Mpdstated - a state tracker for MPD
====================================
Are you tired of loosing your recent position in your podcast/audiobook,
because you switched to a different track?

This was my motivation to write mpdstated: It automaticly restore the position you stopped.

How to use
==========
Install mpdstated and start it like this:

    $ mpdstated --track-path=watched_directory

Replace watched\_directory with your directory, which should be observed.
Let's say your mpd music directory is */home/fred/musik* and you store your podcast in */home/fred/musik/podcasts*,
then your wanted directory is *podcasts*. (sub-directories and sub-sub-directories are allowed too!)

That's all.

For more options see:

    $ mpdstated --help

How it works
==============
mpdstated uses sticker, introduced in mpd v0.15, to store the recent position server side.
(that allows to run mpdstated from a different machine!)

To detect multiple instances of mpdstated the client-to-client protocol is needed.
This feature is currently only avaible in the development version of mpd.

How to build
============
install the following tools/libraries:

  - libmpdclient (the library mpc uses too)
  - vala (implies glib and gobject)
  - cmake

Here a oneliner to install the dependencies under Debian/Ubuntu/Mint:

    apt-get install valac cmake libglib2.0-dev libmpdclient-dev

On Fedora/Centos/Opensuse the following package are needed:

    vala glib2-devel libmpdclient-devel cmake

Clone the repository and cd into it:

    git clone https://github.com/Mic92/mpdstated.git
    cd mpdstated

Then just run the following commands:

    cmake .
    make

If everthing works you get a single binary named mpdstated,
which could be copied in $HOME/bin for example.

If you want to install it to /usr/bin use the following commands.

    cmake -DCMAKE_INSTALL_PREFIX=/usr .
    make
    make install

How to package
==============

Archlinux
---------
Use the PGKBUILD included in the source

DEB and RPM
------------
There is experimental support to provide DEB and RPM via cmake.
After building the binary just run:

    make package

The dependecies are specified in CmakeLists.txt.

So please provide me patches, if something is missing.
