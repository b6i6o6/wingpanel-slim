# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

project (wingpanel-slim)
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

#
# Base bits
#

enable_testing ()

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/wingpanel-slim")
set (GETTEXT_PACKAGE "wingpanel-slim")
set (EXEC_NAME "wingpanel-slim")
set (RELEASE_NAME "Luna")
set (VERSION "0.2.3")
set (VERSION_INFO "luna")
set (CMAKE_C_FLAGS "-ggdb")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

# Add 'make dist' command for creating release tarball
set (CPACK_PACKAGE_VERSION ${VERSION})
set (CPACK_SOURCE_GENERATOR "TGZ")
set (CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${CPACK_PACKAGE_VERSION}")
set (CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;/.bzrignore;~$;${CPACK_SOURCE_IGNORE_FILES}")

include (CPack)
add_custom_target (dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

# Set dependencies
set (WINGPANEL_DEPS "gobject-2.0;glib-2.0;gio-2.0;gee-0.8;gdk-x11-3.0;x11;gtk+-3.0;granite")
set (WINGPANEL_DEPS_NOVALA "gthread-2.0;indicator3-0.4")
find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED ${WINGPANEL_DEPS})
pkg_check_modules (DEPS_NOVALA REQUIRED ${WINGPANEL_DEPS_NOVALA})

# Static Files
file (GLOB desktop_entry "${CMAKE_CURRENT_SOURCE_DIR}/data/wingpanel-slim.desktop")
file (GLOB icon "${CMAKE_CURRENT_SOURCE_DIR}/data/wingpanel-slim.svg")

# Find the Indicator Directory
execute_process (COMMAND ${PKG_CONFIG_EXECUTABLE} indicator3-0.4 --variable=indicatordir OUTPUT_VARIABLE current_indicatordir OUTPUT_STRIP_TRAILING_WHITESPACE)
set (INDICATORDIR ${current_indicatordir})

# Configuration File and Translation
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

# Setup C Libraries
add_definitions(${DEPS_CFLAGS} ${DEPS_NOVALA_CFLAGS} -include config.h)

link_libraries(${DEPS_LIBRARIES} ${DEPS_NOVALA_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS} ${DEPS_NOVALA_DIRS})

# Handle Vala Compilation
find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16" MINIMUM)

include(ValaPrecompile)
vala_precompile (VALA_C ${EXEC_NAME}
    src/WingpanelApp.vala
    src/IndicatorWidget.vala
    src/IndicatorIface.vala
    src/IndicatorLoader.vala

    src/Indicator/IndicatorFileModel.vala
    src/Indicator/IndicatorObjectEntry.vala
    src/Indicator/IndicatorObject.vala
    src/Indicator/IndicatorFactory.vala

    src/Widgets/Panel.vala
    src/Widgets/BasePanel.vala
    src/Widgets/AppButtonPanel.vala
    src/Widgets/AppsButton.vala
    src/Widgets/PanelShadow.vala
    src/Widgets/IndicatorButton.vala
    src/Widgets/MenuBar.vala
    src/Widgets/IndicatorMenubar.vala
    src/Widgets/StyleClass.vala

    src/Services/Settings.vala
    src/Services/IndicatorSorter.vala
    src/Services/AppLauncherService.vala
    src/Services/LauncherRunner.vala

PACKAGES
	${WINGPANEL_DEPS}
CUSTOM_VAPIS
    vapi/config.vapi
    vapi/indicator-0.4.vapi
OPTIONS
	--thread
)

# Settings Schema
include (GSettings)
add_schema ("org.pantheon.desktop.wingpanel-slim.gschema.xml")

# Add Translation Support
add_subdirectory (po)

# Create the Executable
add_executable(${EXEC_NAME} ${VALA_C})

# Installation
install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)
install (FILES ${desktop_entry} DESTINATION ${DATADIR}/applications)
install (FILES ${icon} DESTINATION ${DATADIR}/icons/hicolor/scalable/apps)
