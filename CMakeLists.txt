#####################
# Project mpdstated
#####################
project(mpdstated C)

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
pkg_check_modules(MPDSTATED_DEPENDS REQUIRED
        glib-2.0
        gobject-2.0
        libmpdclient>=2.1)
pkg_check_modules(LIBMPDCLIENT_WITH_C2C QUIET libmpdclient>=2.5)

add_definitions(${MPDSTATED_DEPENDS_CFLAGS})

link_libraries(${MPDSTATED_DEPENDS_LIBRARIES})

link_directories(${MPDSTATED_DEPENDS_LIBRARY_DIRS})

include_directories(${MPDSTATED_DEPENDS_INCLUDE_DIRS})

set(DEF_NO_CLIENT_TO_CLIENT "")
if (NOT LIBMPDCLIENT_WITH_C2C_FOUND)
        set(DEF_NO_CLIENT_TO_CLIENT "NO_CLIENT_TO_CLIENT")
endif(NOT LIBMPDCLIENT_WITH_C2C_FOUND)

vala_precompile(VALA_C
                src/mpdstated.vala
        PACKAGES
                libmpdclient
                posix
                linux
        OPTIONS
                --vapidir=${CMAKE_SOURCE_DIR}/vapi
        DEFINITIONS
                ${DEF_NO_CLIENT_TO_CLIENT}
       )

add_executable(mpdstated ${VALA_C})
install(TARGETS mpdstated
        RUNTIME DESTINATION bin)

# Packages
set(CPACK_PACKAGE_NAME "mpdstated")
set(CPACK_PACKAGE_VERSION 0.3)
set(CPACK_PACKAGE_CONTACT "jthalheim@gmail.com")
set(CPACK_RESOURCE_FILE_LICENSE "LICENSE")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Auto restore recent position for each track in mpd")
set(CPACK_RESOURCE_FILE_LICENSE "LICENSE")
set(CPACK_GENERATOR "DEB;RPM")
set(CPACK_PACKAGE_EXECUTABLES "mpdstated")

set(GITHUB_PAGE "https://github.com/Mic92/mpdstated")
# Debian specific
#set(CPACK_DEBIAN_PACKAGE_DEBUG on)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libmpdclient2 (>= 2.1), libglib2.0, libc6")
set(CPACK_DEBIAN_PACKAGE_SECTION "sound")
#set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS on)
set(CPACK_DEBIAN_PACKAGE_HOMEPAGE ${GITHUB_PAGE})

# RPM specific
set(CPACK_RPM_PACKAGE_LICENSE "GPLv3")
set(CPACK_RPM_PACKAGE_GROUP "Applications/Multimedia")
set(CPACK_RPM_PACKAGE_REQUIRES "libmpdclient >= 2.1, glib2, glibc")
set(CPACK_RPM_PACKAGE_URL ${GITHUB_PAGE})
include(CPack)
