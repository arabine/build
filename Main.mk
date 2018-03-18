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
# DEFINES	+= -DUNICODE -DCONFIG_NATIVE_WINDOWS # FIXME why ?
CFLAGS  = -c -pipe -g -O0 -pedantic -std=c99 -ggdb -Wall -Wextra
CPPFLAGS = -c -pipe -g -O0 -pedantic -ggdb -Wall -Wextra -std=c++11
ARFLAGS = rcs

ifeq ($(OS_DETECTED), WIN32)
CFLAGS  += -fno-keep-inline-dllexport
DEFINES	+= -DUSE_WINDOWS_OS
LDFLAGS += -Wl,-subsystem,console -lws2_32 -lpsapi -lwinmm -static-libgcc -static-libstdc++ -static -lpthread
else

DEFINES	+= -DUSE_UNIX_OS
LDFLAGS += -ldl -lpthread

endif

endif # GCC

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


SOURCES :=


# Include all the modules sub-makefiles in one command
-include $(patsubst %, %/Module.mk, $(ALL_MODULES))


# Deduct objects to build 
OBJECTS := $(addprefix $(OUTDIR),$(patsubst %.c, %.o, $(filter %.c,$(SOURCES))))
OBJECTS += $(addprefix $(OUTDIR),$(patsubst %.cpp, %.o, $(filter %.cpp,$(SOURCES))))


# Include generated dependency files, if any
ifeq ($(ENABLE_DEP), true)
	# List of dependencies
	DEPENDENCIES := $(patsubst %.o,%.d,$(OBJECTS))
	# Dependency flags
	DEPEND_FLAGS = -MMD
endif

INCLUDES_CPY:=$(INCLUDES)

-include $(DEPENDENCIES)

INCLUDES_CPY += $(ALL_MODULES)

$(addprefix $(OUTDIR), %.o): %.c
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) "$(dir $@)"
	$(VERBOSE) $(CC) $(CFLAGS) $(DEFINES) $(addprefix -I, $(INCLUDES_CPY)) $(DEPEND_FLAGS) -o $@ $<

$(addprefix $(OUTDIR), %.o): %.cpp
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) "$(dir $@)"
	$(VERBOSE) $(CPP) $(CPPFLAGS) $(DEFINES) $(addprefix -I, $(INCLUDES_CPY)) $(DEPEND_FLAGS) -o $@ $<

$(addprefix $(OUTDIR), %.o): %.s
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) "$(dir $@)"
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

# Arguments: $1=objects $2=library name
define librarian
	@echo "Invoking: Librarian $(OS_DETECTED)"
	$(VERBOSE) $(AR) $(ARFLAGS) $(OUTDIR)$(strip $(2) $(1))
	@echo "Finished building library: $(strip $(2))"
	@echo " "
endef

# *******************************************************************************
# END OF MAKEFILE								*
# *******************************************************************************
