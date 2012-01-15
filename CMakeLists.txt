#####################
# Project podcastd
#####################
project(podcastd C)

cmake_minimum_required(VERSION 2.6)

# Location where cmake first looks for modules.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)


################################################################
# Configure and find libraries
################################################################

# Find vala
find_package(Vala REQUIRED)
include(${VALA_USE_FILE})

find_package(PkgConfig)
pkg_check_modules(GLIB REQUIRED glib-2.0)
pkg_check_modules(LIBMPDCLIENT REQUIRED libmpdclient)
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)

add_definitions(
        ${GLIB_CFLAGS}
        ${GOBJECT_CFLAGS}
        ${LIBMPDCLIENT_CFLAGS}
        )

link_libraries(
        ${GLIB_LIBRARIES}
        ${GOBJECT_LIBRARIES}
        ${LIBMPDCLIENT_LIBRARIES}
        )

link_directories(
        ${GLIB_LIBRARY_DIRS}
        ${GOBJECT_LIBRARY_DIRS}
        ${LIBMPDCLIENT_LIBRARY_DIRS}
        )

include_directories(
        ${GLIB_INCLUDE_DIRS}
        ${GOBJECT_INCLUDE_DIRS}
        ${LIBMPDCLIENT_INCLUDE_DIRS}
        )

vala_precompile(VALA_C
                src/podcastd.vala
        PACKAGES
                libmpdclient
                posix
        OPTIONS
                --vapidir=${CMAKE_SOURCE_DIR}/vapi
       )

add_executable(podcastd ${VALA_C})
target_link_libraries(podcastd
        ${GLIB_LIBRARIES}
        ${GOBJECT_LIBRARIES}
        ${LIBMPDCLIENT_LIBRARIES}
        )
install(TARGETS podcastd
        RUNTIME DESTINATION bin)

# Packages
set(CPACK_PACKAGE_NAME "podcastd")
set(CPACK_PACKAGE_VERSION 0.2)
set(CPACK_PACKAGE_CONTACT "jthalheim@gmail.com")
set(CPACK_RESOURCE_FILE_LICENSE "LICENSE")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Auto restore recent position for each podcast in mpd")
set(CPACK_RESOURCE_FILE_LICENSE "LICENSE")
set(CPACK_GENERATOR "DEB;RPM")
set(CPACK_PACKAGE_EXECUTABLES "podcastd")

set(GITHUB_PAGE "https://github.com/Mic92/podcastd")
# Debian specific
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libmpdclient2 (>= 2.5), libglib2.0, libc6")
set(CPACK_DEBIAN_PACKAGE_SECTION "sound")
set(CPACK_DEBIAN_PACKAGE_HOMEPAGE ${GITHUB_PAGE})

# RPM specific
set(CPACK_RPM_PACKAGE_LICENSE "GPL")
set(CPACK_RPM_PACKAGE_GROUP "Applications/Multimedia")
set(CPACK_RPM_PACKAGE_URL ${GITHUB_PAGE})
include(CPack)
