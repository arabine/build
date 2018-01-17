# *******************************************************************************
# Main.mk
# Build engine targetted for component/module architecture.
# TODO:
#   - Export GCC configuration into external file
#   - Support more toolchains
# *******************************************************************************

# this turns off the suffix rules built into make
.SUFFIXES:

# *******************************************************************************
# OS DETECTION
# *******************************************************************************
OS_DETECTED=

ifeq ($(OS),Windows_NT)
    OS_DETECTED := WIN32
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        OS_DETECTED := LINUX
    endif
endif

ifeq (gcc, $(findstring gcc, $(ARCH)))
# Compiler setting
CC      = gcc
CPP		= g++
AR      = ar
AS      = as
LD 		= g++
LDFLAGS = $(addprefix -L, $(APP_LIBPATH))

# FIXME: different CFLAGS for debug/release targets
DEFINES	+= -DUNICODE -DCONFIG_NATIVE_WINDOWS
CFLAGS  = -c -pedantic -std=c99 -Wall -Wextra -fms-extensions
CPPFLAGS = -c -pedantic -Wall -Wextra -std=c++14 -fms-extensions


ifeq ($(TARGET), release)
RELEASE_FLAGS := -O2
CFLAGS += $(RELEASE_FLAGS)
CPPFLAGS += $(RELEASE_FLAGS)
else
DEBUG_FLAGS := -ggdb -pipe -g -O0
CFLAGS += $(DEBUG_FLAGS)
CPPFLAGS += $(DEBUG_FLAGS)
endif

ifeq ($(OS_DETECTED), WIN32)
CFLAGS  += -fno-keep-inline-dllexport
DEFINES	+= -DUSE_WINDOWS_OS
LDFLAGS += -Wl,-subsystem,console -lws2_32 -lpsapi -lwinmm -static-libgcc -static-libstdc++ -static -lpthread
else

DEFINES	+= -DUSE_UNIX_OS
LDFLAGS += -ldl -lpthread

endif

ifeq ($(ENABLE_DEP), true)
	# List of dependencies
	DEPENDENCIES = $(OBJECTS:%.o=%.d)
	# Dependency flags
	DEPEND_FLAGS = -MMD
endif

endif

DEL_FILE      := rm -f
CHK_DIR_EXISTS := test -d
MKDIR         := mkdir -p
COPY_FILE     := cp -f
COPY_DIR      := cp -f -R
MOVE          := mv -f

# Verbosity shows all the commands that are executed by the makefile, and their arguments
VERBOSE            ?= @

# If we want to build one module, overrire the module list
ifdef MODULE
ALL_MODULES = $(MODULE)
else
ALL_MODULES = $(sort $(APP_MODULES))
endif

# Figure out where we are. Taken from Android build system thanks!
define my-dir
$(strip \
  $(eval LOCAL_MODULE_MAKEFILE := $$(lastword $$(MAKEFILE_LIST))) \
  $(if $(filter $(BUILD_SYSTEM)/% $(OUTDIR)/%,$(LOCAL_MODULE_MAKEFILE)), \
    $(error my-dir must be called before including any other makefile.) \
   , \
    $(patsubst %/,%,$(dir $(LOCAL_MODULE_MAKEFILE))) \
   ) \
 )
endef


SOURCES 	:=
INCLUDES 	:=

# Include all the modules sub-makefiles in one command
-include $(patsubst %, %/Module.mk, $(ALL_MODULES))

# Deduct objects to build 
OBJECTS := $(addprefix $(OUTDIR),$(patsubst %.c, %.o, $(filter %.c,$(SOURCES))))
OBJECTS += $(addprefix $(OUTDIR),$(patsubst %.cpp, %.o, $(filter %.cpp,$(SOURCES))))

# Include generated dependency files, if any
-include $(DEPENDENCIES)


INCLUDES += $(ALL_MODULES)

$(addprefix $(OUTDIR), %.o): %.c
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) -p "$(dir $@)"
	$(VERBOSE) $(CC) $(CFLAGS) $(DEFINES) $(addprefix -I, $(INCLUDES)) $(DEPEND_FLAGS) -o $@ $<

$(addprefix $(OUTDIR), %.o): %.cpp
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) -p "$(dir $@)"
	$(VERBOSE) $(CPP) $(CPPFLAGS) $(DEFINES) $(addprefix -I, $(INCLUDES)) $(DEPEND_FLAGS) -o $@ $<

$(addprefix $(OUTDIR), %.o): %.s
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) -p "$(dir $@)"
	$(VERBOSE) $(AS) $(ASFLAGS) -o $@ $< 
	
# *******************************************************************************
# GENERIC
# *******************************************************************************

# Arguments: $1=objects $2=libs $3=executable name
define linker
	@echo "Invoking: Linker $(OS_DETECTED)"
	$(VERBOSE) $(LD) $(1) $(2) $(LDFLAGS) -o $(OUTDIR)$(strip $(3))
	@echo "Finished building target: $(strip $(3))"
	@echo " "
endef


# *******************************************************************************
# 								   END OF MAKEFILE								*
# *******************************************************************************
