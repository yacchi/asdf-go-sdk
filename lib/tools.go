package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/Masterminds/semver"
	"go/build"
	"log"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"
)

const (
	VersionsUrl = "https://go.dev/dl/?mode=json&include=all"
)

// release
// https://pkg.go.dev/golang.org/x/website/internal/dl
type release struct {
	Version string `json:"version"`
	Stable  bool   `json:"stable"`
	Files   []struct {
		Filename       string    `json:"filename"`
		OS             string    `json:"os"`
		Arch           string    `json:"arch"`
		Version        string    `json:"version"`
		Checksum       string    `json:"-" datastore:",noindex"` // SHA1; deprecated
		ChecksumSHA256 string    `json:"sha256" datastore:",noindex"`
		Size           int64     `json:"size" datastore:",noindex"`
		Kind           string    `json:"kind"` // "archive", "installer", "source"
		Uploaded       time.Time `json:"-"`
	} `json:"files"`
	semver *semver.Version
}

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

func listReleases() []*release {
	r, err := http.NewRequest("GET", VersionsUrl, nil)
	if err != nil {
		log.Fatalln(err)
	}

	ret, err := http.DefaultClient.Do(r)
	if err != nil {
		log.Fatalln(err)
	}
	defer ret.Body.Close()

	var releases []*release
	if err := json.NewDecoder(ret.Body).Decode(&releases); err != nil {
		log.Fatalln(err)
	}

	var filtered []*release
NEXT:
	for _, r := range releases {
		for _, f := range r.Files {
			if f.OS == getOS() {
				if r.semver, err = NewGoVer(r.Version[2:]); err != nil {
					log.Printf("invalid version format of '%s'\n", r.Version)
				}
				filtered = append(filtered, r)
				continue NEXT
			}
		}
	}

	return filtered
}

func reverseReleases(r []*release) []*release {
	for i := 0; i < len(r)/2; i++ {
		r[i], r[len(r)-i-1] = r[len(r)-i-1], r[i]
	}
	return r
}

func printSDKVersions(lowLimit *semver.Version) {
	for _, r := range reverseReleases(listReleases()) {
		if lowLimit != nil {
			if r.semver.LessThan(lowLimit) {
				continue
			}
		}
		fmt.Println(r.Version[2:]) // trim 'go' prefix
	}
}

func printLatestSDKVersions() {
	for _, r := range listReleases() {
		if r.Stable {
			fmt.Println(r.Version[2:]) // trim 'go' prefix
			return
		}
	}
}

func resolveVersion(v string) {
	if _, err := NewGoVer(v); err == nil {
		fmt.Println(v)
		return
	}
	if c, err := semver.NewConstraint(v); err == nil {
		versions := listReleases()
		for _, v := range versions {
			if c.Check(v.semver) {
				fmt.Println(v.Version[2:]) // trim 'go' prefix
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
	case "latest-sdk-version":
		printLatestSDKVersions()
	case "resolve-version":
		if len(os.Args) < 3 {
			printHelp()
		}
		resolveVersion(os.Args[2])
	default:
		printHelp()
	}
}
