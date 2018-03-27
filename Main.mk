# *******************************************************************************
# Main.mk
# Build engine targetted for component/module architecture.
# TODO:
#   - Export GCC configuration into external file
#   - Support more toolchains
# *******************************************************************************

# this turns off the suffix rules built into make
.SUFFIXES:

TARGET_ARCH :=
TARGET_SUFFIX := 

# *******************************************************************************
# COMPILER DETECTION
# *******************************************************************************
ifeq (gcc, $(findstring gcc, $(ARCH)))
# Compiler setting
CC      = $(GCC_PREFIX)gcc
CPP		= $(GCC_PREFIX)g++
AR      = $(GCC_PREFIX)ar
AS      = $(GCC_PREFIX)gcc -x assembler-with-cpp
LD 		= $(GCC_PREFIX)g++
SZ 		= $(GCC_PREFIX)size
CP		= $(PREFIX)objcopy
HEX		= $(CP) -O ihex
BIN		= $(CP) -O binary -S
LIBDIR 	= $(addprefix -L, $(APP_LIBPATH))

# FIXME: different CFLAGS for debug/release targets
ARFLAGS = rcs

ifeq (cm4, $(findstring cm4, $(ARCH)))

OPT 			:= -Og
CFLAGS 			:= -c $(OPT) -gdwarf-2 -Wall -fdata-sections -ffunction-sections
TARGET_ARCH 	:= Cortex-M4
CPU 			:= -mcpu=cortex-m4
TARGET_SUFFIX 	:= .elf
MCU 			:= $(CPU) -mfpu=fpv4-sp-d16 -mthumb -mfloat-abi=hard
CFLAGS 			+= $(MCU)
CPPFLAGS 		+= $(MCU)

# libraries
LIBS 			= -lc -lm -lnosys 
LDFLAGS 		= $(MCU) -specs=nano.specs -T$(APP_LDSCRIPT) $(LIBDIR) $(LIBS) -Wl,-Map=$(OUTDIR)/$(PROJECT).map,--cref -Wl,--gc-sections

# Dependency flags
CFLAGS += -MMD -MP

endif # Cortex-M4

# *******************************************************************************
# HOST ARCHITECTURE: Unix, Windows, MacOS X
# *******************************************************************************
ifeq (host, $(findstring host, $(ARCH)))

    ifeq ($(OS),Windows_NT)
        TARGET_ARCH := WIN32
    else
        UNAME_S := $(shell uname -s)
        ifeq ($(UNAME_S),Linux)
            TARGET_ARCH := LINUX
        endif
    endif

CFLAGS  = -c -pipe -g -O0 -pedantic -std=c99 -ggdb -Wall -Wextra
CPPFLAGS = -c -pipe -g -O0 -pedantic -ggdb -Wall -Wextra -std=c++11

    ifeq ($(TARGET_ARCH), WIN32)
        CFLAGS  += -fno-keep-inline-dllexport
        DEFINES	+= -DUSE_WINDOWS_OS
        LDFLAGS += -Wl,-subsystem,console -lws2_32 -lpsapi -lwinmm -static-libgcc -static-libstdc++ -static -lpthread
    else
        DEFINES	+= -DUSE_UNIX_OS
        LDFLAGS += -ldl -lpthread
    endif
endif # endif host architecture


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
INCLUDES :=

# Include all the modules sub-makefiles in one command
-include $(patsubst %, %/Module.mk, $(ALL_MODULES))


# Deduct objects to build 
OBJECTS := $(addprefix $(OUTDIR),$(patsubst %.c, %.o, $(filter %.c,$(SOURCES))))
OBJECTS += $(addprefix $(OUTDIR),$(patsubst %.cpp, %.o, $(filter %.cpp,$(SOURCES))))
OBJECTS += $(addprefix $(OUTDIR),$(patsubst %.s, %.o, $(filter %.s,$(SOURCES))))


DEPENDENCIES := $(patsubst %.o,%.d,$(OBJECTS))

# Include generated dependency files, if any
#-include $(DEPENDENCIES)

INCLUDES += $(ALL_MODULES)

$(addprefix $(OUTDIR), %.o): %.c
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) "$(dir $@)"
	$(VERBOSE) $(CC) $(CFLAGS) $(DEFINES) $(addprefix -I, $(INCLUDES)) $(DEPEND_FLAGS) -o $@ $<

$(addprefix $(OUTDIR), %.o): %.cpp
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) "$(dir $@)"
	$(VERBOSE) $(CPP) $(CPPFLAGS) $(DEFINES) $(addprefix -I, $(INCLUDES)) $(DEPEND_FLAGS) -o $@ $<

$(addprefix $(OUTDIR), %.o): %.s
	@echo "Building file: $(notdir $@)"
	$(VERBOSE) $(MKDIR) "$(dir $@)"
	$(VERBOSE) $(AS) $(CFLAGS) -o $@ $<

$(OUTDIR)$(PROJECT).hex: $(OUTDIR)$(PROJECT).elf | $(OUTDIR)
	$(HEX) $< $@


# *******************************************************************************
# GENERIC
# *******************************************************************************

TARGET_NAME	:= $(PROJECT)$(TARGET_SUFFIX)
EXECUTABLE 	:= $(OUTDIR)$(TARGET_NAME)

.PHONY: $(EXECUTABLE)
$(EXECUTABLE): $(OBJECTS)
	@echo "Invoking: Linker $(TARGET_ARCH)"
	$(CC) $(OBJECTS) $(APP_LIBS) $(LDFLAGS) -o $(EXECUTABLE)
	@echo "Finished building target: $(TARGET_NAME)"
	@echo " "
	$(SZ) $@

.PHONY: all
all: $(EXECUTABLE) $(OUTDIR)$(PROJECT).hex


# Arguments: $1=objects $2=library name
define librarian
	@echo "Invoking: Librarian $(TARGET_ARCH)"
	$(VERBOSE) $(AR) $(ARFLAGS) $(OUTDIR)$(strip $(2) $(1))
	@echo "Finished building library: $(strip $(2))"
	@echo " "
endef

# *******************************************************************************
# END OF MAKEFILE								*
# *******************************************************************************
