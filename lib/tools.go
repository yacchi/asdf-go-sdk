package main

import (
	"errors"
	"fmt"
	"github.com/Masterminds/semver"
	"go/build"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
	"log"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
)

const (
	VersionsUrl    = "https://golang.org/dl/"
	DownloadPrefix = "/dl/go"
)

const (
	DownloadPrefixLen = len(DownloadPrefix)
)

func getOS() string {
	return runtime.GOOS
}

func goroot(version string) (string, error) {
	home, err := homedir()
	if err != nil {
		return "", fmt.Errorf("failed to get home directory: %v", err)
	}
	return filepath.Join(home, "sdk", version), nil
}

func homedir() (string, error) {
	switch getOS() {
	case "plan9":
		return "", fmt.Errorf("%q not yet supported", runtime.GOOS)
	case "windows":
		if dir := os.Getenv("USERPROFILE"); dir != "" {
			return dir, nil
		}
		return "", errors.New("can't find user home directory; %USERPROFILE% is empty")
	default:
		if dir := os.Getenv("HOME"); dir != "" {
			return dir, nil
		}
		if u, err := user.Current(); err == nil && u.HomeDir != "" {
			return u.HomeDir, nil
		}
		return "", errors.New("can't find user home directory; $HOME is empty")
	}
}

func printSDKPath() {
	if root, err := goroot("DUMMY"); err != nil {
		log.Fatal(err)
	} else {
		fmt.Println(filepath.Dir(root))
	}
	os.Exit(0)
}

func printGOPATH() {
	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		gopath = build.Default.GOPATH
	}
	fmt.Println(gopath)
}

var v0Regex = regexp.MustCompile(`^(\d+)\.(\d+)\.?(\d*)([\w\d]+)$`)

func NewGoVer(vs string) (*semver.Version, error) {
	v, err := semver.NewVersion(vs)
	if err == nil {
		return v, nil
	}
	m := v0Regex.FindStringSubmatch(vs)
	if 4 < len(m) {
		patch := m[3]
		if patch == "" {
			patch = "0"
		}
		return semver.NewVersion(fmt.Sprintf("%s.%s.%s-%s", m[1], m[2], patch, m[4]))
	}
	return nil, err
}

func OriginalGoVersion(v *semver.Version) string {
	if v.Patch() == 0 {
		// ex. 1.17, 1.17rc1
		return fmt.Sprintf("%d.%d%s", v.Major(), v.Minor(), v.Prerelease())
	}
	if v.Prerelease() != "" {
		// ex. 1.9.2rc2
		return fmt.Sprintf("%d.%d.%d%s", v.Major(), v.Minor(), v.Patch(), v.Prerelease())
	}
	// standard release version
	return v.String()
}

func findVersions(node *html.Node) (ret semver.Collection) {
	archiveSuffix := "." + runtime.GOOS + "-" + runtime.GOARCH
	for elem := node.FirstChild; elem != nil; elem = elem.NextSibling {
		if elem.Type == html.ElementNode {
			if elem.DataAtom == atom.A {
				for _, v := range elem.Attr {
					if v.Key != "href" {
						continue
					}
					extPos := strings.Index(v.Val, archiveSuffix)
					if strings.HasPrefix(v.Val, DownloadPrefix) && 0 < extPos {
						vStr := v.Val[DownloadPrefixLen:extPos]
						if parsed, err := NewGoVer(vStr); err != nil {
							continue
						} else {
							ret = append(ret, parsed)
						}
					}
				}
			}
			ret = append(ret, findVersions(elem)...)
		}
	}

	sort.Sort(ret)
	return ret
}

func listSDKVersions() (sdkVers semver.Collection) {
	r, err := http.NewRequest("GET", VersionsUrl, nil)
	if err != nil {
		log.Fatalln(err)
	}

	ret, err := http.DefaultClient.Do(r)
	if err != nil {
		log.Fatalln(err)
	}
	defer ret.Body.Close()

	node, err := html.Parse(ret.Body)
	if err != nil {
		log.Fatalln(err)
	}
	versions := findVersions(node)
	unique := map[string]struct{}{}

	for _, v := range versions {
		if _, exists := unique[v.String()]; exists {
			continue
		}
		sdkVers = append(sdkVers, v)
		unique[v.String()] = struct{}{}
	}
	return
}

func printSDKVersions(lowLimit *semver.Version) {
	for _, v := range listSDKVersions() {
		if lowLimit != nil {
			if v.LessThan(lowLimit) {
				continue
			}
		}
		fmt.Println(OriginalGoVersion(v))
	}
}

func resolveVersion(v string) {
	if _, err := NewGoVer(v); err == nil {
		fmt.Println(v)
		return
	}
	if c, err := semver.NewConstraint(v); err == nil {
		versions := listSDKVersions()
		sort.Sort(sort.Reverse(versions))
		for _, v := range versions {
			if c.Check(v) {
				fmt.Println(OriginalGoVersion(v))
				return
			}
		}
	}
	fmt.Println(v)
}

func printHelp() {
	bin := filepath.Base(os.Args[0])
	fmt.Printf(`Usage:
	%s <command> [arguments]

Commands:
	version                          Print Go version (without 'go' prefix)
	sdk-path                         Print Go SDK path
	gopath                           Print GOPATH
	sdk-versions [LOW_LIMIT_VERSION] List Go SDK versions
	resolve-version VERSION          Resolve semver of Go
`, bin)
	os.Exit(0)
}

func main() {
	if len(os.Args) < 2 {
		printHelp()
	}

	switch os.Args[1] {
	case "version":
		fmt.Println(strings.TrimLeft(runtime.Version(), "go"))
	case "sdk-path":
		printSDKPath()
	case "gopath":
		printGOPATH()
	case "sdk-versions":
		if 2 < len(os.Args) {
			if c, err := NewGoVer(os.Args[2]); err != nil {
				log.Fatalln(err)
			} else {
				printSDKVersions(c)
			}
		} else {
			printSDKVersions(nil)
		}
	case "resolve-version":
		if len(os.Args) < 3 {
			printHelp()
		}
		resolveVersion(os.Args[2])
	default:
		printHelp()
	}
}
