.PHONY: all test cover tags clean release build prep-integration sanity cl

GIT ?= /usr/local/cpanel/3rdparty/bin/git
RELEASE_TAG ?= release
PERL_BIN=/usr/local/cpanel/3rdparty/perl/536/bin
PERL_LIB=/usr/local/cpanel/3rdparty/perl/536/lib
VERSION=`cat version`

all:
	$(MAKE) build
	$(MAKE) test
	$(MAKE) cover

sanity:
	@for file in $$(find lib -type f -name "*.pm" | sort); do \
		$(PERL_BIN)/perl -cw -Ilib $$file || exit 1; \
	done

test: sanity
	-$(MAKE) elevate-cpanel
	$(PERL_BIN)/prove t/00_load.t
	$(PERL_BIN)/yath test -j8 t/*.t --exclude-pattern t/03_fatpack-script.t

build:
	rm -f elevate-cpanel
	$(MAKE) elevate-cpanel

prep-integration:
	curl -fsSL https://raw.githubusercontent.com/skaji/cpm/main/cpm > ./cpm
	chmod -v +x ./cpm
	/scripts/update_local_rpm_versions --edit target_settings.perl-enhanced installed
	./cpm install Test::PerlTidy
	cp -v local/lib/perl5/Test/PerlTidy.pm $(PERL_LIB)/Test/ && rm -Rfv local/
	/scripts/check_cpanel_pkgs --fix --long-list --no-digest
	/bin/bash t/integration/setup

cover:
	/usr/bin/rm -rf cover_db
	HARNESS_PERL_SWITCHES="-MDevel::Cover=-loose_perms,on,-coverage,statement,branch,condition,subroutine,-ignore,.,-select,elevate-cpanel" $(PERL_BIN)/prove t/*.t ||:
	$(PERL_BIN)/cover -silent
	find cover_db -type f -exec chmod 644 {} \;
	find cover_db -type d -exec chmod 755 {} \;

tags:
	/usr/bin/ctags -R --languages=perl --extra=+q script lib t

elevate-cpanel: $(wildcard lib/**/*) script/elevate-cpanel.PL
	USE_CPANEL_PERL_FOR_PERLSTATIC=1 maint/perlpkg.static \
				       --dir=lib \
				       --no-cpstrict \
				       --no-try-tiny \
				       --no-http-tiny \
				       --no-file-path-tiny \
				       --leave-broken \
				       script/$@.PL
	mv script/$@.PL.static $@
	MARKER="`cat maint/marker`" $(PERL_BIN)/perl -pi -e 's|^(#!/usr/local/cpanel/3rdparty/bin/perl)|$$1\n\n$$ENV{MARKER}\n|' $@
	VERSION=${VERSION} $(PERL_BIN)/perl -pi -e 's/(^use constant VERSION =>) 1;/$$1 $$ENV{VERSION};/' $@
	$(PERL_BIN)/perltidy -b -bext="/" $@
	chmod +x $@
	$(PERL_BIN)/perl -cw elevate-cpanel

clean:
	rm -f tags
	rm -f ./cpm

release: build
	$(GIT) tag -f $(RELEASE_TAG)	
	$(GIT) tag -f v${VERSION}
	$(GIT) push pub main
	$(GIT) push --force pub $(RELEASE_TAG)
	$(GIT) push --force pub v${VERSION}
	$(MAKE) bump_version
	$(GIT) push ent main
	$(GIT) push --force ent $(RELEASE_TAG)
	$(GIT) push --force ent v${VERSION}

bump_version: version := $(shell dc -f version -e '1 + p')
bump_version:
	echo -n $(version) > version
	$(MAKE) build;
	$(GIT) add version elevate-cpanel
	$(GIT) commit -m "Bump version to $(version) after release"
cl:
	maint/generate_changelog

