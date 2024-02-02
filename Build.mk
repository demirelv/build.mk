WSDIR		?= $(CURDIR)/../
PROJECT_DIR	?= $(CURDIR)
DISTDIRS	:= ${PROJECT_DIR}/build
OUTDIR		:= ${DISTDIRS}
DESTDIR		?= ${PROJECT_DIR}/install
PROJECT_NAME	?= $(subst /,_, ${PROJECT_DIR})
PROJECT_PACKAGE ?= ${PROJECT_NAME}.tar.bz2

CC		:= $(CROSS_COMPILE_PREFIX)gcc
LD		:= $(CROSS_COMPILE_PREFIX)ld
AR		:= $(CROSS_COMPILE_PREFIX)ar
Q		:= 
RM		:= rm -rf
MKDIR		:= mkdir -p
CP		:= cp -rf
CD		:= cd
TAR		:= tar
CCS		:= checkpatch.pl --no-tree -f

_CFLAGS		:= -Wall -Wextra -Werror -pipe -g3 -O2 -fsigned-char -fno-strict-aliasing -fPIC -Werror=unused-result $(CFLAGS) $(EXTRA_CFLAGS) -I.
_LDFLAGS	:= $(LDFLAGS) $(EXTRA_LDFLAGS) -L.

MAKE		:= CFLAGS="$(CFLAGS)" EXTRA_CFLAGS="$(EXTRA_CFLAGS)" LDFLAGS="$(LDFLAGS)" EXTRA_LDFLAGS="$(EXTRA_LDFLAGS)" $(MAKE) --no-print-directory
MAKEDIR		:= WSDIR="${WSDIR}" PROJECT_DIR="$(PROJECT_DIR)" DESTDIR="$(DESTDIR)" $(MAKE)

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
	$(Q) $(CD) $1 && $(MAKE) WSDIR=$(CURDIR) package
endef

define depends-define
$(addsuffix _depend_build_ins, $1):
	$(Q) $(CD) $(WSDIR)/$1 && $(MAKE) WSDIR=$(WSDIR) build install
endef

define dir-define
$(addsuffix _all, $1):
	@+ $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' all
$(addsuffix _build, $1):
	@+ $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' build
$(addsuffix _clean, $1):
	@+ $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' clean
$(addsuffix _install, $1):
	@+ $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' install
$(addsuffix _uninstall, $1):
	@+ $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' uninstall
$(addsuffix _codestyle, $1):
	@+ $(MAKEDIR) OUTDIR=${OUTDIR}/$1 -C '$1' checkstyle
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

define base-define
$(eval $(foreach H,$($1-header-y), $(eval $(call header-define,$H))))
$(eval $(foreach S,$($1-source-y), $(eval $(call code-style-define,$S))))
$(eval $(foreach D,$($1-depends-y),$(eval $(call depends-define,$D))))

$(eval $1-objs		= $(patsubst %.c,${OUTDIR}/.$1/%.o,$($1-source-y)))
$(eval $1-incs		= $(addprefix -I, $($1-include-y)) $(patsubst %,-I ${WSDIR}/%/install/usr/include,$($1-depends-y)))
$(eval $1-libps		= $(addprefix -L, ./ $($1-library-path-y)) $(patsubst %,-L ${WSDIR}/%/install/usr/lib,$($1-depends-y)))

${OUTDIR}/.$1:
	$(Q)$(MKDIR) $$@
${OUTDIR}/.$1/%.o: %.c
	$(Q) echo CC $$<; $(MKDIR) $$(dir $$@); $(CC) $(_CFLAGS) $($1-cflags-y) $($1-incs) -c $$< -o $$@
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
${OUTDIR}/$1: ${OUTDIR}/.$1 $($1-objs)
	$(Q) echo CC $$@; $(CC) $($1-objs) -o $$@ ${_LDFLAGS} $($1-ldflags-y) $($1-libps) $($1-library-y)
endef

define library-define
$(eval $(call base-define,$1))
${OUTDIR}/$1: ${OUTDIR}/.$1 $($1-objs)
	$(Q) echo CC $$@; $(CC) -shared $($1-objs) -o $$@ ${_LDFLAGS} $($1-ldflags-y) $($1-libps) $($1-library-y)
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

${PROJECT_PACKAGE}:
	$(Q) ${TAR} -C ${DESTDIR} -cjvf $@ .

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
package-pre: $(addsuffix _package, $(proj-y))
package-post: package-def
package-def: ${PROJECT_PACKAGE}
	@true
checkstyle: $(addsuffix _codestyle, $(dir-y))
checkstyle: $(addsuffix _codestyle, $(library-y))
checkstyle: $(addsuffix _codestyle, $(target-y))
	@true

%: %-pre %-def %-post
	@true

