.PHONY: test cover tags clean release build

GIT ?= /usr/local/cpanel/3rdparty/bin/git
RELEASE_TAG ?= release
PERL_BIN=/usr/local/cpanel/3rdparty/perl/536/bin

test: elevate-cpanel
	perl -cw elevate-cpanel
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
	USE_CPANEL_PERL_FOR_PERLSTATIC=1 /usr/local/cpanel/bin/perlpkg \
				       --dir=lib \
				       --no-cpstrict \
				       --no-try-tiny \
				       --no-http-tiny \
				       --no-file-path-tiny \
				       --leave-broken \
				       script/elevate-cpanel.PL
	mv script/elevate-cpanel.PL.static elevate-cpanel
	perltidy elevate-cpanel && mv elevate-cpanel.tdy elevate-cpanel

build:
	rm -f elevate-cpanel
	$(MAKE) elevate-cpanel

clean:
	rm -f tags

release: version := $(shell dc -f version -e '1 + p')
release:
	echo -n $(version) > version
	sed -i -re "/^#<<V/,+1 s/VERSION => [0-9]*;/VERSION => $(version);/" elevate-cpanel
	$(GIT) commit -m "Release version $(version)" -- version elevate-cpanel
	$(GIT) tag -f $(RELEASE_TAG)
	$(GIT) tag -f v$(version)
	$(GIT) push origin
	$(GIT) push --force origin tag $(RELEASE_TAG)
	$(GIT) push --force origin tag v$(version)
