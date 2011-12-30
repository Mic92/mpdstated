pkgname=podcastd-git
pkgver=20111230
pkgrel=1
pkgdesc="Make mpd remember, where you stop your podcast"
url="https://github.com/Mic92/podcastd"
license=('GPL')
depends=('glib2' 'libmpdclient' 'cmake')
makedepends=('git' 'vala')
arch=('i686' 'x86_64')

_gitroot="https://Mic92@github.com/Mic92/podcastd.git"
_gitname="podcastd"

build() {
    cd $srcdir
    msg "Connecting to GIT server...."

    if [ -d $_gitname ] ; then
	cd $_gitname && git pull origin
	msg "The local files are updated."
    else
	git clone $_gitroot $_gitname
    fi

    msg "GIT checkout done or server timeout"
    msg "Starting make..."

    rm -rf $srcdir/$_gitname-build
    git clone $srcdir/$_gitname $srcdir/$_gitname-build

    cd $srcdir/$_gitname-build

    cmake -DCMAKE_INSTALL_PREFIX=/usr .
    make
}

package() {
    cd $srcdir/$_gitname-build
    make DESTDIR=$pkgdir install
}
