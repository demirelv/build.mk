WSDIR		?= $(CURDIR)/../
PROJECT_DIR	?= $(CURDIR)
OUTDIR		:= $(PROJECT_DIR)/build
DESTDIR		?= $(PROJECT_DIR)/install
PROJECT_NAME	?= $(subst /,_, ${PROJECT_DIR})
PROJECT_PACKAGE ?= ${PROJECT_NAME}.tar.bz2

CPP		:= $(CROSS_COMPILE_PREFIX)g++
CC		:= $(CROSS_COMPILE_PREFIX)gcc
LD		:= $(CROSS_COMPILE_PREFIX)ld
AR		:= $(CROSS_COMPILE_PREFIX)ar
RM		:= rm -rf
MKDIR		:= mkdir -p
CP		:= cp -rf
CD		:= cd
TAR		:= tar
CCS		:= checkpatch.pl --no-tree -f

_CPPFLAGS	:= -Wall -Wextra -Werror -pipe -g3 -O2 -fsigned-char -fno-strict-aliasing -fPIC -Werror=unused-result $(CPPFLAGS) $(EXTRA_CPPFLAGS) -I.
_CFLAGS		:= -Wall -Wextra -Werror -pipe -g3 -O2 -fsigned-char -fno-strict-aliasing -fPIC -Werror=unused-result $(CFLAGS) $(EXTRA_CFLAGS) -I.
_LDFLAGS	:= $(LDFLAGS) $(EXTRA_LDFLAGS) -L.

MAKE		:= CPPFLAGS="$(CPPFLAGS)" EXTRA_CPPFLAGS="$(EXTRA_CPPFLAGS)" CFLAGS="$(CFLAGS)" EXTRA_CFLAGS="$(EXTRA_CFLAGS)" LDFLAGS="$(LDFLAGS)" EXTRA_LDFLAGS="$(EXTRA_LDFLAGS)" $(MAKE)

ifneq ($(V)$(VERBOSE),)
    Q =
    MAKE += V="$(V)$(VERBOSE)"
else
    Q = @
    MAKE += --no-print-directory
endif

MAKEDIR		:= WSDIR="${WSDIR}" PROJECT_DIR="$(PROJECT_DIR)" DESTDIR="$(DESTDIR)" $(MAKE)

# Header dependencies are emitted as a side effect of the compile (-MMD) and
# fed back in via -include, down in c-define. The old separate -M pass
# compiled every file twice AND wrote a dep file whose target was the bare
# basename ("foo.o") instead of the real path under OUTDIR, so nothing ever
# matched -- and the .d files were never included anyway. Net effect: a
# header change did not trigger a rebuild, and binaries mixing old and new
# struct layouts were produced silently. -MT pins the target, -MP keeps a
# deleted header from breaking the build.
_compile_c	= $(CC) $(_CFLAGS) $($1-cflags-y) $($1-incs) -MMD -MP -MF $$@.d -MT $$@ -c $$< -o $$@
# C++ tarafinda bagimlilik takibi HIC yoktu -- C'deki gibi bozuk degil, yok.
# Ayni sonuc: header degisikligi yeniden derlemiyor.
_compile_cpp	= $(CPP) $(_CPPFLAGS) $($1-cppflags-y) $($1-incs) -MMD -MP -MF $$@.d -MT $$@ -c $$< -o $$@
_link_cpp	= $(CPP) $($1-objs) -o $$@ ${_LDFLAGS} $($1-ldflags-y) $($1-libps) $($1-library-y)
_link_c		= $(CC) $($1-objs) -o $$@ ${_LDFLAGS} $($1-ldflags-y) $($1-libps) $($1-library-y)
_link_so_c	= $(CC) -shared $($1-objs) -o $$@ ${_LDFLAGS} $($1-ldflags-y) $($1-libps) $($1-library-y)
_link_so_cpp	= $(CPP) -shared $($1-objs) -o $$@ ${_LDFLAGS} $($1-ldflags-y) $($1-libps) $($1-library-y)

compile_c	= echo "$(_compile_c)" > $$@.cmd ; $(_compile_c)
compile_cpp	= echo "$(_compile_cpp)" > $$@.cmd ; $(_compile_cpp)
link_c		= echo "$(_link_c)" > $$@.cmd ; $(_link_c)
link_cpp	= echo "$(_link_cpp)" > $$@.cmd ; $(_link_cpp)
link_so_c	= echo "$(_link_so_c)" > $$@.cmd ; $(_link_so_c)
link_so_cpp	= echo "$(_link_so_cpp)" > $$@.cmd ; $(_link_so_cpp)


define proj-define
$(addsuffix _all, $1):
	$(Q) $(CD) $1 && $(MAKE) WSDIR=$(CURDIR) build install
$(addsuffix _build, $1):
	$(Q) $(CD) $1 && $(MAKE) WSDIR=$(CURDIR) build
$(addsuffix _clean, $1):
	$(Q) $(CD) $1 && $(MAKE) WSDIR=$(CURDIR) clean
$(addsuffix _install, $1):
	$(Q) $(CD) $1 && $(MAKE) WSDIR=$(CURDIR) install
$(addsuffix _uninstall, $1):
	$(Q) $(CD) $1 && $(MAKE) WSDIR=$(CURDIR) uninstall
$(addsuffix _codestyle, $1):
	$(Q) $(CD) $1 && $(MAKE) WSDIR=$(CURDIR) checkstyle
$(addsuffix _package, $1):
	$(Q) $(CD) $1 && $(MAKE) WSDIR=$(CURDIR) PROJECT_NAME=$1 PROJECT_PACKAGE=$1.tar.bz2 package
$(addsuffix _pk-post, $1): $(addsuffix _package, $1)
	$(Q) echo install $1/$1.tar.bz2 ${DESTDIR}
	$(Q) ${MKDIR} ${DESTDIR}; ${TAR} -xjvf $1/$1.tar.bz2 --directory=${DESTDIR}
endef

define depends-define
$(addsuffix _depend_build_ins, $1):
	$(Q) $(CD) $(WSDIR)/$1 && $(MAKE) WSDIR=$(WSDIR) \
		PROJECT_DIR=$(WSDIR)/$1 DESTDIR=$(WSDIR)/$1/install OUTDIR=$(WSDIR)/$1/build build install
endef

define dir-define
$(addsuffix _all, $1):
	$(Q) $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' all
$(addsuffix _build, $1):
	$(Q) $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' build
$(addsuffix _clean, $1):
	$(Q) $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' clean
$(addsuffix _install, $1):
	$(Q) $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' install
$(addsuffix _uninstall, $1):
	$(Q) $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' uninstall
$(addsuffix _codestyle, $1):
	$(Q) $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' checkstyle
endef

define header-define
${OUTDIR}:
	$(Q)$(MKDIR) $$@
$(addsuffix _header, $1): ${OUTDIR}
	$(Q) echo HEADER $1; $(CP) $1 ${OUTDIR}/
endef

define code-style-define
$(addsuffix _codestyle, $1):
	$(Q) echo CCS $1; $(CCS) $1;
endef

define c-define
$(eval $1-objs		= $(patsubst %.c,${OUTDIR}/.$1/%.o,$($1-source-y)))
#${OUTDIR}/.$1:
#	$(Q)$(MKDIR) $$@
${OUTDIR}/.$1/%.o: %.c
	$(Q) echo CC $$<; $(MKDIR) $$(dir $$@); $(compile_c)
# Absent on the first build; that is fine, everything compiles anyway.
-include $(patsubst %.c,${OUTDIR}/.$1/%.o.d,$($1-source-y))
endef

define cpp-define
$(eval $1-objs		= $(patsubst %.cpp,${OUTDIR}/.$1/%.o,$($1-source-y)))
${OUTDIR}/.$1:
	$(Q)$(MKDIR) $$@
${OUTDIR}/.$1/%.o: %.cpp
	$(Q) echo CPP $$<; $(MKDIR) $$(dir $$@); $(compile_cpp)
# Absent on the first build; that is fine, everything compiles anyway.
-include $(patsubst %.cpp,${OUTDIR}/.$1/%.o.d,$($1-source-y))
endef

define base-define
$(eval $(foreach H,$($1-header-y), $(eval $(call header-define,$H))))
$(eval $(foreach S,$($1-source-y), $(eval $(call code-style-define,$S))))
$(eval $(foreach D,$($1-depends-y),$(eval $(call depends-define,$D))))

$(eval $1-incs		= $(addprefix -I, $($1-include-y)) $(patsubst %,-I ${WSDIR}/%/install/usr/include,$($1-depends-y)))
$(eval $1-libps		= $(addprefix -L, ./ $($1-library-path-y)) $(patsubst %,-L ${WSDIR}/%/install/usr/lib,$($1-depends-y)))

$(eval $(if $(filter $($1-cpp),y),$(eval $(call cpp-define,$1)),$(eval $(call c-define,$1))))

$(addsuffix _all, $1): $(addsuffix _depends, $1) ${OUTDIR}/$1 $(addsuffix _header, $1)
	@true
$(addsuffix _build, $1): $(addsuffix _depends, $1) ${OUTDIR}/$1 $(addsuffix _header, $1)
	@true
$(addsuffix _clean, $1):
	$(RM) ${OUTDIR}
$(addsuffix _header, $1): $(addsuffix _header, $($1-header-y))
	@true
$(addsuffix _codestyle, $1): $(addsuffix _codestyle, $($1-source-y))
	@true
$(addsuffix _depends, $1): $(addsuffix _depend_build_ins, $($1-depends-y))
	@true
endef

define target-define
$(eval $(call base-define,$1))
${OUTDIR}/$1: $($1-objs)
ifneq ($($1-cpp),)
	$(Q) echo link $$@; $(link_cpp)
else
	$(Q) echo link $$(notdir $$@); $(link_c)
endif
endef

define library-define
$(eval $(call base-define,$1))
${OUTDIR}/$1: $($1-objs)
ifneq ($($1-cpp),)
	$(Q) echo link $$@; $(link_so_cpp)
else
	$(Q) echo link $$@; $(link_so_c)
endif
endef

define install-define
$(subst /,-, $(dir $(word 2, $(subst :, ,$1)))):
	$(Q)$(MKDIR) ${DESTDIR}${PREFIX}/$(dir $(word 2, $(subst :, ,$1)))
$(addsuffix _install, $(subst /,-, $(subst :,-, $1))):$(subst /,-, $(dir $(word 2, $(subst :, ,$1))))
	$(Q) echo INSTALL $(word 1, $(subst :, ,$1)); $(if $(wildcard ${OUTDIR}/$(word 1, $(subst :, ,$1))), $(CP) ${OUTDIR}/$(word 1, $(subst :, ,$1)) ${DESTDIR}${PREFIX}/$(word 2, $(subst :, ,$1)), $(CP) ${PROJECT_DIR}/$(word 1, $(subst :, ,$1)) ${DESTDIR}${PREFIX}/$(word 2, $(subst :, ,$1)))
$(addsuffix _uninstall, $(subst /,-, $(subst :,-, $1))):
	$(Q) echo REMOVE $(word 1, $(subst :, ,$1)); $(RM) ${DESTDIR}${PREFIX}/$(word 2, $(subst :, ,$1))/$(word 1, $(subst :, ,$1))
endef

$(eval $(foreach P,$(proj-y),$(eval $(call proj-define,$P))))
$(eval $(foreach D,$(dir-y),$(eval $(call dir-define,$D))))
$(eval $(foreach T,$(target-y), $(eval $(call target-define,$T))))
$(eval $(foreach L,$(library-y), $(eval $(call library-define,$L))))
$(eval $(foreach V,$(install-y), $(eval $(call install-define,$V))))

all: $(addsuffix _all, $(proj-y))
all: $(addsuffix _all, $(dir-y))
all: $(addsuffix _all, $(library-y))
all: $(addsuffix _all, $(target-y))
	@true
build: $(addsuffix _build, $(proj-y))
build: $(addsuffix _build, $(dir-y))
build: $(addsuffix _build, $(library-y))
build: $(addsuffix _build, $(target-y))
	@true
clean: $(addsuffix _clean, $(proj-y))
clean: $(addsuffix _clean, $(target-y))
clean: $(addsuffix _clean, $(library-y))
clean: $(addsuffix _clean, $(dir-y))
	@true
install: $(addsuffix _install, $(proj-y))
install: $(addsuffix _install, $(dir-y))
install: $(addsuffix _install, $(subst /,-, $(subst :,-,$(install-y))))
	@true
uninstall: $(addsuffix _uninstall, $(proj-y))
uninstall: $(addsuffix _uninstall, $(dir-y))
unisstall: $(addsuffix _uninstall, $(subst /,-, $(subst :,-,$(install-y))))
	@true
package-pre:
package-post: package-def
package-def: $(addsuffix _package, $(proj-y)) $(addsuffix _pk-post, $(proj-y))
ifneq ($(package-tar-y),n)
	$(Q) echo create ${PROJECT_PACKAGE} for ${PROJECT_NAME}
	$(Q) ${TAR} -C ${DESTDIR} -cjvf ${PROJECT_PACKAGE} .
endif

# release — sadece alt projeleri paketleyen genel repo'da (proj-y dolu) tanımlı;
# yaprak projelerde yok. Her RELEASE_PROJS projesini temiz derleyip
# <proj>_package tar'ını üretir, RELEASE_DIR'e kopyalar, RELEASE_ROOTFS'a açar
# ve rootfs'ten tek birleşik RELEASE_TAR oluşturur.
#
# Repo Makefile'ında override edilir (include Build.mk'den ÖNCE):
#   RELEASE_PROJS    alt proje listesi        (default: tüm proj-y)
#   RELEASE_NAME     birleşik paket adı
#   RELEASE_VER      versiyon                 (default: YYYY.MM.DD)
#   RELEASE_ARCH     noarch|amd64|arm64       (default: amd64)
#   RELEASE_EXCLUDES tar --exclude'ları (örn. secret env dosyaları)
#
# DİKKAT: DESTDIR'i komut satırından geçirme — alt-make'in package hedefine
# yayılıp yanlış dizini tar'latır.
RELEASE_PROJS	?= $(proj-y)
RELEASE_NAME	?= $(PROJECT_NAME)
RELEASE_VER	?= $(shell date +%Y.%m.%d)
RELEASE_ARCH	?= amd64
RELEASE_DIR	?= $(CURDIR)/release
RELEASE_ROOTFS	:= $(RELEASE_DIR)/rootfs
RELEASE_TAR	:= $(RELEASE_DIR)/$(RELEASE_NAME)-$(RELEASE_VER).$(RELEASE_ARCH).tar.bz2
RELEASE_EXCLUDES ?=

ifneq ($(strip $(proj-y)),)
.PHONY: release
release:
	$(Q) $(RM) $(RELEASE_DIR)
	$(Q) $(MKDIR) $(RELEASE_ROOTFS)
	$(Q) set -e; for p in $(RELEASE_PROJS); do \
		echo "RELEASE $$p"; \
		$(RM) $$p/install $$p/$$p.tar.bz2; \
		$(MAKE) $${p}_clean $${p}_all $${p}_package; \
		$(CP) $$p/$$p.tar.bz2 $(RELEASE_DIR)/; \
		$(TAR) -xjf $(RELEASE_DIR)/$$p.tar.bz2 --directory=$(RELEASE_ROOTFS); \
	done
	$(Q) echo "RELEASE $(notdir $(RELEASE_TAR))"
	$(Q) $(TAR) --numeric-owner --owner=0 --group=0 $(RELEASE_EXCLUDES) \
		-cjf $(RELEASE_TAR) --directory=$(RELEASE_ROOTFS) .
endif

checkstyle: $(addsuffix _codestyle, $(proj-y))
checkstyle: $(addsuffix _codestyle, $(dir-y))
checkstyle: $(addsuffix _codestyle, $(library-y))
checkstyle: $(addsuffix _codestyle, $(target-y))
	@true

%: %-pre %-def %-post
	@true
