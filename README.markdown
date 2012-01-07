Podcastd - a podcast tracker for MPD
====================================
Are you tired of loosing your recent position in your podcast/audiobook,
because you switched to a different track?

This was my motivation to write podcastd: It automaticly restore the position you stopped.

How to use
==========
Install podcastd and start it like this:

    $ podcastd --podcast-path=podcast_directory

Replace podcast_directory with your directory, where your podcast are located.
Let's say your mpd music directory is */home/fred/musik* and you store your podcast in */home/fred/musik/podcasts*,
then your podcast directory is *podcasts*. (sub-directories and sub-sub-directories are allowed too!)

That's all.

For more options see:

    $ podcastd --help

How it works
==============
podcastd uses this awesome sticker feature introduced in mpd v0.15 to store the recent position server side.
(that allows to run podcastd from a different machine!)

How to build
============
install the following tools/libraries:

  - libmpdclient (the library mpc uses too)
  - vala (implies glib and gobject)
  - cmake

Clone the repository and cd into it:

    git clone https://github.com/Mic92/podcastd.git
    cd podcastd

Then just run the following commands:

    cmake .
    make

If everthing works you get a single binary named podcastd,
which could be copied in $HOME/bin for example.

If you want to install it to /usr/bin use the following commands.

    cmake -DCMAKE_INSTALL_PREFIX=/usr .
    make
    make install

How to package
==============

Currently there are no deb/rpm-packages.
I would really appreciate, if someone with a launchpad account
or opensuse build-service account could do this.

For archlinux exists a PKGBUILD, which you could use.
