.PHONY: all test cover tags clean release build sanity

GIT ?= /usr/local/cpanel/3rdparty/bin/git
RELEASE_TAG ?= release
PERL_BIN=/usr/local/cpanel/3rdparty/perl/536/bin

all:
	$(MAKE) build
	$(MAKE) test
	$(MAKE) cover

sanity:
	@for file in $$(find lib -type f -name "*.pm" | sort); do \
		perl -cw -Ilib $$file || exit 1; \
	done

test: sanity
	-$(MAKE) elevate-cpanel
	/usr/local/cpanel/3rdparty/bin/prove t/00_load.t
	/usr/local/cpanel/3rdparty/bin/yath test -j8 t/*.t

cover:
	/usr/bin/rm -rf cover_db
	HARNESS_PERL_SWITCHES="-MDevel::Cover=-loose_perms,on,-coverage,statement,branch,condition,subroutine,-ignore,.,-select,elevate-cpanel" prove -j8 t/*.t ||:
	$(PERL_BIN)/cover -silent
	find cover_db -type f -exec chmod 644 {} \;
	find cover_db -type d -exec chmod 755 {} \;

tags:
	/usr/bin/ctags -R --languages=perl elevate-cpanel t

elevate-cpanel: $(wildcard lib/**/*) script/elevate-cpanel.PL
	USE_CPANEL_PERL_FOR_PERLSTATIC=1 maint/perlpkg.static \
				       --dir=lib \
				       --no-cpstrict \
				       --no-try-tiny \
				       --no-http-tiny \
				       --no-file-path-tiny \
				       --leave-broken \
				       script/$@.PL
	@mv script/$@.PL.static $@
	@MARKER="`cat maint/marker`" perl -pi -e 's|^(#!/usr/local/cpanel/3rdparty/bin/perl)|$$1\n\n$$ENV{MARKER}\n|' $@
	@VERSION="`cat version`" perl -pi -e 's/(^use constant VERSION =>) 1;/$$1 $$ENV{VERSION};/' $@
	@perltidy -b -bext="/" $@
	@chmod +x $@
	perl -cw elevate-cpanel

build:
	rm -f elevate-cpanel
	$(MAKE) elevate-cpanel

clean:
	rm -f tags

release: build
	$(GIT) tag -f $(RELEASE_TAG)
	@VERSION="`cat version`" $(GIT) tag -f v$VERSION
	$(GIT) push origin
	$(GIT) push --force origin tag $(RELEASE_TAG)
	@VERSION="`cat version`" $(GIT) push --force origin tag v$VERSION
	$(MAKE) bump_version

bump_version: version := $(shell dc -f version -e '1 + p')
bump_version:
	echo -n $(version) > version
	$(GIT) add version
	$(GIT) commit -m "Bump version to $(version) after release"
