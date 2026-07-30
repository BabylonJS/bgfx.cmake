# bgfx.cmake - bgfx building in cmake
# Written in 2017 by Joshua Brookover <joshua.al.brookover@gmail.com>
#
# To the extent possible under law, the author(s) have dedicated all copyright
# and related and neighboring rights to this software to the public domain
# worldwide. This software is distributed without any warranty.
#
# You should have received a copy of the CC0 Public Domain Dedication along with
# this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

# To prevent this warning: https://cmake.org/cmake/help/git-stage/policy/CMP0072.html
if(POLICY CMP0072)
	cmake_policy(SET CMP0072 NEW)
endif()

# Ensure the directory exists
if(NOT IS_DIRECTORY ${BGFX_DIR})
	message(SEND_ERROR "Could not load bgfx, directory does not exist. ${BGFX_DIR}")
	return()
endif()

# Grab the bgfx source files
file(
	GLOB
	BGFX_SOURCES
	${BGFX_DIR}/src/*.cpp
	${BGFX_DIR}/src/*.h
	${BGFX_DIR}/include/bgfx/*.h
	${BGFX_DIR}/include/bgfx/c99/*.h
)

if(APPLE)
	file(GLOB BGFX_OBJC_SOURCES ${BGFX_DIR}/src/*.mm)
	list(APPEND BGFX_SOURCES ${BGFX_OBJC_SOURCES})
	list(REMOVE_ITEM BGFX_SOURCES ${BGFX_DIR}/src/amalgamated.cpp)
	set(BGFX_AMALGAMATED_SOURCE ${BGFX_DIR}/src/amalgamated.mm)
else()
	set(BGFX_AMALGAMATED_SOURCE ${BGFX_DIR}/src/amalgamated.cpp)
endif()

if(BGFX_AMALGAMATED)
	set(BGFX_NOBUILD ${BGFX_SOURCES})
	list(REMOVE_ITEM BGFX_NOBUILD ${BGFX_AMALGAMATED_SOURCE})
	foreach(BGFX_SRC ${BGFX_NOBUILD})
		set_source_files_properties(${BGFX_SRC} PROPERTIES HEADER_FILE_ONLY ON)
	endforeach()
else()
	# Do not build using amalgamated sources
	set_source_files_properties(${BGFX_AMALGAMATED_SOURCE} PROPERTIES HEADER_FILE_ONLY ON)
endif()

# Create the bgfx target
if(BGFX_LIBRARY_TYPE STREQUAL STATIC)
	add_library(bgfx STATIC ${BGFX_SOURCES})
else()
	add_library(bgfx SHARED ${BGFX_SOURCES})
	target_compile_definitions(bgfx PUBLIC BGFX_SHARED_LIB_BUILD=1)
endif()

if(BGFX_CONFIG_RENDERER_WEBGPU)
	include(${CMAKE_CURRENT_LIST_DIR}/3rdparty/webgpu.cmake)
	target_compile_definitions(bgfx PRIVATE BGFX_CONFIG_RENDERER_WEBGPU=1)
	if(EMSCRIPTEN)
		target_link_options(bgfx PRIVATE "-s USE_WEBGPU=1")
	else()
		target_link_libraries(bgfx PRIVATE webgpu)
	endif()
endif()

if(EMSCRIPTEN)
	target_link_options(bgfx PUBLIC "-sMAX_WEBGL_VERSION=2")
endif()

if(NOT ${BGFX_OPENGL_VERSION} STREQUAL "")
	target_compile_definitions(bgfx PRIVATE BGFX_CONFIG_RENDERER_OPENGL_MIN_VERSION=${BGFX_OPENGL_VERSION})
endif()

if(NOT ${BGFX_OPENGLES_VERSION} STREQUAL "")
	target_compile_definitions(bgfx PRIVATE BGFX_CONFIG_RENDERER_OPENGLES_MIN_VERSION=${BGFX_OPENGLES_VERSION})
endif()

if(NOT ${BGFX_CONFIG_DEFAULT_MAX_ENCODERS} STREQUAL "")
	target_compile_definitions(
		bgfx
		PUBLIC
			"BGFX_CONFIG_DEFAULT_MAX_ENCODERS=$<IF:$<BOOL:${BGFX_CONFIG_MULTITHREADED}>,${BGFX_CONFIG_DEFAULT_MAX_ENCODERS},1>"
	)
endif()

if(BGFX_WITH_WAYLAND)
	target_compile_definitions(bgfx PRIVATE "WL_EGL_PLATFORM=1")
	target_link_libraries(bgfx PRIVATE wayland-egl)
endif()

# Forward bgfx compile-time settings that the project has configured.
#
# The named cache entries in the top level CMakeLists.txt cover the settings most
# projects reach for, but bgfx has many more of them -- other pool sizes, cache sizes,
# buffer sizes, the draw call block size. Forwarding only a fixed list means anything
# outside it cannot be configured through bgfx.cmake at all, so consumers end up adding
# their own target_compile_definitions after this. Those land later on the command line
# and silently win, which turns a setting that is also on the list into two conflicting
# definitions. Forward every BGFX_CONFIG_ variable the project has set instead, so there
# is one place a setting can come from.
#
# Values are passed through as written rather than being required to be numeric. bgfx
# spells most of its own defaults as expressions, including six of the settings that used
# to be on the fixed list -- BGFX_CONFIG_MAX_TEXTURES is (4<<10) -- so a numeric test
# would quietly discard a value a project had every reason to write that way.
#
# CMake booleans are skipped because the C preprocessor cannot use them. Those settings
# are declared with option() and are turned into definitions further down, where they can
# be evaluated per configuration. They are excluded by name as well, so that setting one
# of them to 0 or 1 does not produce a second, conflicting definition.
set(BGFX_FORWARDED_CONFIG_OPTIONS
	"BGFX_CONFIG_MULTITHREADED"
	"BGFX_CONFIG_DEBUG_ANNOTATION"
	"BGFX_CONFIG_RENDERER_WEBGPU"
)
# cmake_dependent_option() defines <option>_AVAILABLE alongside the option itself. That is
# bookkeeping for the module rather than a bgfx setting, and bgfx has no setting of its own
# ending in _AVAILABLE, so exclude it wherever an excluded option can have produced one.
set(BGFX_FORWARDED_CONFIG_EXCLUDE ${BGFX_FORWARDED_CONFIG_OPTIONS})
foreach(BGFX_FORWARDED_CONFIG_OPTION IN LISTS BGFX_FORWARDED_CONFIG_OPTIONS)
	list(APPEND BGFX_FORWARDED_CONFIG_EXCLUDE "${BGFX_FORWARDED_CONFIG_OPTION}_AVAILABLE")
endforeach()
get_cmake_property(BGFX_FORWARDED_CONFIG_VARIABLES VARIABLES)
list(FILTER BGFX_FORWARDED_CONFIG_VARIABLES INCLUDE REGEX "^BGFX_CONFIG_")
list(REMOVE_ITEM BGFX_FORWARDED_CONFIG_VARIABLES ${BGFX_FORWARDED_CONFIG_EXCLUDE})
list(SORT BGFX_FORWARDED_CONFIG_VARIABLES)
foreach(BGFX_FORWARDED_CONFIG_VARIABLE IN LISTS BGFX_FORWARDED_CONFIG_VARIABLES)
	set(BGFX_FORWARDED_CONFIG_VALUE "${${BGFX_FORWARDED_CONFIG_VARIABLE}}")
	string(TOUPPER "${BGFX_FORWARDED_CONFIG_VALUE}" BGFX_FORWARDED_CONFIG_VALUE_UPPER)
	if(BGFX_FORWARDED_CONFIG_VALUE STREQUAL "")
		continue()
	endif()
	if(BGFX_FORWARDED_CONFIG_VALUE_UPPER MATCHES "^(ON|OFF|TRUE|FALSE|YES|NO|Y|N|IGNORE|NOTFOUND|.*-NOTFOUND)$")
		continue()
	endif()
	target_compile_definitions(
		bgfx PUBLIC "${BGFX_FORWARDED_CONFIG_VARIABLE}=${BGFX_FORWARDED_CONFIG_VALUE}"
	)
endforeach()

# Special Visual Studio Flags
if(MSVC)
	target_compile_definitions(bgfx PRIVATE "_CRT_SECURE_NO_WARNINGS")
endif()

# Add debug config required in bx headers since bx is private
target_compile_definitions(
	bgfx
	PUBLIC
		"BX_CONFIG_DEBUG=$<OR:$<CONFIG:Debug>,$<BOOL:${BX_CONFIG_DEBUG}>>"
		"BGFX_CONFIG_DEBUG_ANNOTATION=$<AND:$<NOT:$<STREQUAL:${CMAKE_SYSTEM_NAME},WindowsStore>>,$<OR:$<CONFIG:Debug>,$<BOOL:${BGFX_CONFIG_DEBUG_ANNOTATION}>>>"
		"BGFX_CONFIG_MULTITHREADED=$<BOOL:${BGFX_CONFIG_MULTITHREADED}>"
)

# directx-headers
set(DIRECTX_HEADERS)
if(UNIX
   AND NOT APPLE
   AND NOT EMSCRIPTEN
   AND NOT ANDROID
) # Only Linux
	set(DIRECTX_HEADERS
		${BGFX_DIR}/3rdparty/directx-headers/include/directx ${BGFX_DIR}/3rdparty/directx-headers/include
		${BGFX_DIR}/3rdparty/directx-headers/include/wsl/stubs
	)
elseif(WIN32) # Only Windows
	set(DIRECTX_HEADERS ${BGFX_DIR}/3rdparty/directx-headers/include/directx
						${BGFX_DIR}/3rdparty/directx-headers/include
	)
endif()

# Includes
target_include_directories(
	bgfx PRIVATE ${DIRECTX_HEADERS} ${BGFX_DIR}/3rdparty ${BGFX_DIR}/3rdparty/khronos
	PUBLIC $<BUILD_INTERFACE:${BGFX_DIR}/include> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# bgfx depends on bx and bimg
target_link_libraries(bgfx PRIVATE bx bimg)

# Frameworks required on iOS, tvOS and macOS
if(${CMAKE_SYSTEM_NAME} MATCHES iOS|tvOS)
	target_link_libraries(
		bgfx
		PUBLIC
			"-framework OpenGLES -framework Metal -framework UIKit -framework CoreGraphics -framework QuartzCore -framework IOKit -framework CoreFoundation"
	)
elseif(APPLE)
	find_library(COCOA_LIBRARY Cocoa)
	find_library(METAL_LIBRARY Metal)
	find_library(QUARTZCORE_LIBRARY QuartzCore)
	find_library(IOKIT_LIBRARY IOKit)
	find_library(COREFOUNDATION_LIBRARY CoreFoundation)
	mark_as_advanced(COCOA_LIBRARY)
	mark_as_advanced(METAL_LIBRARY)
	mark_as_advanced(QUARTZCORE_LIBRARY)
	mark_as_advanced(IOKIT_LIBRARY)
	mark_as_advanced(COREFOUNDATION_LIBRARY)
	target_link_libraries(
		bgfx PUBLIC ${COCOA_LIBRARY} ${METAL_LIBRARY} ${QUARTZCORE_LIBRARY} ${IOKIT_LIBRARY} ${COREFOUNDATION_LIBRARY}
	)
endif()

if(UNIX
   AND NOT APPLE
   AND NOT EMSCRIPTEN
   AND NOT ANDROID
)
	find_package(X11 REQUIRED)
	find_package(OpenGL REQUIRED)
	#The following commented libraries are linked by bx
	#find_package(Threads REQUIRED)
	#find_library(LIBRT_LIBRARIES rt)
	#find_library(LIBDL_LIBRARIES dl)
	target_link_libraries(bgfx PUBLIC ${X11_LIBRARIES} ${OPENGL_LIBRARIES})
endif()

# Exclude mm files if not on OS X
if(NOT APPLE)
	set_source_files_properties(${BGFX_DIR}/src/glcontext_eagl.mm PROPERTIES HEADER_FILE_ONLY ON)
	set_source_files_properties(${BGFX_DIR}/src/glcontext_nsgl.mm PROPERTIES HEADER_FILE_ONLY ON)
	set_source_files_properties(${BGFX_DIR}/src/renderer_mtl.mm PROPERTIES HEADER_FILE_ONLY ON)
endif()

# Exclude glx context on non-unix
if(NOT UNIX OR APPLE)
	set_source_files_properties(${BGFX_DIR}/src/glcontext_glx.cpp PROPERTIES HEADER_FILE_ONLY ON)
endif()

# Put in a "bgfx" folder in Visual Studio
set_target_properties(bgfx PROPERTIES FOLDER "bgfx")

# in Xcode we need to specify this file as objective-c++ (instead of renaming to .mm)
if(XCODE)
	set_source_files_properties(
		${BGFX_DIR}/src/renderer_vk.cpp PROPERTIES LANGUAGE OBJCXX XCODE_EXPLICIT_FILE_TYPE sourcecode.cpp.objcpp
	)
endif()

if(BGFX_INSTALL)
	install(
		TARGETS bgfx
		EXPORT "${TARGETS_EXPORT_NAME}"
		LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
		ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
		RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
		INCLUDES
		DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
	)

	install(DIRECTORY ${BGFX_DIR}/include/bgfx DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

	# header required for shader compilation
	install(FILES ${BGFX_DIR}/src/bgfx_shader.sh ${BGFX_DIR}/src/bgfx_compute.sh
			DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/bgfx"
	)
endif()
