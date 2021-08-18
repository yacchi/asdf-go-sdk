package main

import (
	"errors"
	"fmt"
	"github.com/hashicorp/go-version"
	"go/build"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
	"log"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

const (
	VersionsUrl        = "https://golang.org/dl/"
	DownloadPrefix     = "/dl/go"
	SourceFileExtChunk = ".src"
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

func findVersions(node *html.Node) (ret version.Collection) {
	for elem := node.FirstChild; elem != nil; elem = elem.NextSibling {
		if elem.Type == html.ElementNode {
			if elem.DataAtom == atom.A {
				for _, v := range elem.Attr {
					if v.Key != "href" {
						continue
					}
					extPos := strings.Index(v.Val, SourceFileExtChunk)
					if strings.HasPrefix(v.Val, DownloadPrefix) && 0 < extPos {
						if parsed, err := version.NewVersion(v.Val[DownloadPrefixLen:extPos]); err != nil {
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

func listSDKVersions() {
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
		fmt.Println(v.Original())
		unique[v.String()] = struct{}{}
	}
}

func printHelp() {
	bin := filepath.Base(os.Args[0])
	fmt.Printf(`Usage:
	%s <command> [arguments]

Commands:
	version     Print Go version (without 'go' prefix)
	sdk-path	Print Go SDK path
	gopath		Print GOPATH
	sdk-versions	List Go SDK versions
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
		listSDKVersions()
	default:
		printHelp()
	}
}
