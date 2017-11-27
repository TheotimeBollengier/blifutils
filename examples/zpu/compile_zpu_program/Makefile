TARGET = zpu_helloworld

SRCC       += main.c

OPTIMISATION = 2
WARNINGS = -W -Wall

## The toolchain path ##
#TC      = /opt/zpugcc/bin/zpu-elf
TC      = zpu-elf
CC      = $(TC)-gcc
LD      = $(TC)-gcc
AR      = $(TC)-ar
SIZE    = $(TC)-size
OBJCOPY = $(TC)-objcopy
OBJDUMP = $(TC)-objdump



OBJS      += $(SRCC:.c=.o) $(SRCS:.s=.o)
ASM       += $(SRCC:.c=.S)


INCLUDEPATH  += -I.
COMMONFLAGS  += -O$(OPTIMISATION) -phi -g
CFLAGS       += $(COMMONFLAGS) $(INCLUDEPATH) $(WARNINGS)
LDLIBS       += -lm
LIBDIR       += -L .



LDFLAGS      += $(COMMONFLAGS) $(LIBDIR)


LDFLAGS += -Wl,--gc-sections -Wl,--relax -Wl,-Map=./$(TARGET).map

ifdef LD_FILE
LDFLAGS += -Wl,-T$(LD_FILE)
endif


all: $(TARGET).bin


################################################################################
############################### ELF output #####################################
################################################################################


$(TARGET).elf: $(OBJS) 
	$(LD) -o $(TARGET).elf $(LDFLAGS) $(OBJS) -Wl,--no-whole-archive $(LDLIBS)
	$(SIZE) $(TARGET).elf

%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o : %.s
	$(CC) $(CFLAGS) -x assembler-with-cpp -c $< -o $@

disasm: $(TARGET).elf
	$(OBJDUMP) -h -S -D -z $(TARGET).elf > $(TARGET).lss


################################################################################
################################### ASM ########################################
################################################################################


asm: $(ASM)

%.S : %.c
	$(CC) $(CFLAGS) -S $< -o $@


################################################################################
############################ HEX and BIN output ################################
################################################################################


hex: $(TARGET).hex 

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $(TARGET).elf $@

bin: $(TARGET).bin

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $(TARGET).elf $@

size: $(TARGET).elf
	$(SIZE) $<


################################################################################
################################### Clean ######################################
################################################################################


clean:
	@rm -fv $(OBJS) 
	@rm -fv $(ASM) 
	@rm -fv $(TARGET).hex
	@rm -fv $(TARGET).bin 
	@rm -fv $(TARGET)_BigEndian.bin 
	@rm -fv $(TARGET)_BigEndian_back.bin 
	@rm -fv $(TARGET).elf
	@rm -fv $(TARGET).map
	@rm -fv $(TARGET).lss



################################################################################
################################### END ########################################
################################################################################
