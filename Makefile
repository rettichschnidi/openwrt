# Makefile for OpenWrt
#
# Copyright (C) 2007 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

TOPDIR:=${CURDIR}
LC_ALL:=C
LANG:=C
TZ:=UTC
export TOPDIR LC_ALL LANG TZ

empty:=
space:= $(empty) $(empty)
$(if $(findstring $(space),$(TOPDIR)),$(error ERROR: The path to the LEDE directory must not include any spaces))

world:

include $(TOPDIR)/include/host.mk

ifneq ($(OPENWRT_BUILD),1)
  _SINGLE=export MAKEFLAGS=$(space);

  override OPENWRT_BUILD=1
  export OPENWRT_BUILD
  GREP_OPTIONS=
  export GREP_OPTIONS
  include $(TOPDIR)/include/debug.mk
  include $(TOPDIR)/include/depends.mk
  include $(TOPDIR)/include/toplevel.mk
else
  include rules.mk
  include $(INCLUDE_DIR)/depends.mk
  include $(INCLUDE_DIR)/subdir.mk
  include target/Makefile
  include package/Makefile
  include tools/Makefile
  include toolchain/Makefile

$(toolchain/stamp-install): $(tools/stamp-install)
$(target/stamp-compile): $(toolchain/stamp-install) $(tools/stamp-install) $(BUILD_DIR)/.prepared
$(package/stamp-compile): $(target/stamp-compile) $(package/stamp-cleanup)
$(package/stamp-install): $(package/stamp-compile)
$(target/stamp-install): $(package/stamp-compile) $(package/stamp-install)
check: $(tools/stamp-check) $(toolchain/stamp-check) $(package/stamp-check)

printdb:
	@true

prepare: $(target/stamp-compile)

clean: FORCE
	rm -rf $(BUILD_DIR) $(STAGING_DIR) $(BIN_DIR) $(OUTPUT_DIR)/packages/$(ARCH_PACKAGES) $(BUILD_LOG_DIR) $(TOPDIR)/staging_dir/packages

dirclean: clean
	rm -rf $(STAGING_DIR_HOST) $(TOOLCHAIN_DIR) $(BUILD_DIR_HOST) $(BUILD_DIR_TOOLCHAIN)
	rm -rf $(TMP_DIR)

ifndef DUMP_TARGET_DB
$(BUILD_DIR)/.prepared: Makefile
	@mkdir -p $$(dirname $@)
	@touch $@

tmp/.prereq_packages: .config
	unset ERROR; \
	for package in $(sort $(prereq-y) $(prereq-m)); do \
		$(_SINGLE)$(NO_TRACE_MAKE) -s -r -C package/$$package prereq || ERROR=1; \
	done; \
	if [ -n "$$ERROR" ]; then \
		echo "Package prerequisite check failed."; \
		false; \
	fi
	touch $@
endif

# check prerequisites before starting to build
prereq: $(target/stamp-prereq) tmp/.prereq_packages
	@if [ ! -f "$(INCLUDE_DIR)/site/$(ARCH)" ]; then \
		echo 'ERROR: Missing site config for architecture "$(ARCH)" !'; \
		echo '       The missing file will cause configure scripts to fail during compilation.'; \
		echo '       Please provide a "$(INCLUDE_DIR)/site/$(ARCH)" file and restart the build.'; \
		exit 1; \
	fi

checksum: FORCE
	$(call sha256sums,$(BIN_DIR))

diffconfig: FORCE
	mkdir -p $(BIN_DIR)
	$(SCRIPT_DIR)/diffconfig.sh > $(BIN_DIR)/config.seed

prepare: .config $(tools/stamp-install) $(toolchain/stamp-install)
world: prepare $(target/stamp-compile) $(package/stamp-compile) $(package/stamp-install) $(target/stamp-install) FORCE
	$(_SINGLE)$(SUBMAKE) -r package/index
	$(_SINGLE)$(SUBMAKE) -r diffconfig
	$(_SINGLE)$(SUBMAKE) -r checksum

.PHONY: clean dirclean prereq prepare world package/symlinks package/symlinks-install package/symlinks-clean

endif

digiges-update-feeds:
	$(TOPDIR)/scripts/feeds update -a
	$(TOPDIR)/scripts/feeds install -a
digiges-clean:
	rm -rf $(TOPDIR)/files
	rm -f $(TOPDIR)/.config
digiges-configure-tor: digiges-clean
	cat $(TOPDIR)/digiges-config/extension-tor >> $(TOPDIR)/.config
	cat $(TOPDIR)/digiges-config/extension-iperf3 >> $(TOPDIR)/.config
	cp -r $(TOPDIR)/digiges-files/tor $(TOPDIR)/files
digiges-tor: digiges-update-feeds digiges-configure-tor defconfig world
.PHONY: digiges-update-feeds digiges-clean digiges-configure-tor

digiges-configure-gl-ar150-tor: digiges-configure-tor
	cat $(TOPDIR)/digiges-config/base-gl-ar150 >> $(TOPDIR)/.config
	cp $(TOPDIR)/digiges-files/gl-ar150-tor/etc/config/wireless $(TOPDIR)/files/etc/config
digiges-gl-ar150-tor: digiges-update-feeds digiges-configure-gl-ar150-tor defconfig world
.PHONY: digiges-configure-gl-ar150-tor digiges-gl-ar150-tor

digiges-configure-gl-ar150-speedtest: digiges-configure-gl-ar150-tor
	cp -r $(TOPDIR)/digiges-files/iperf3-on-startup/etc/init.d $(TOPDIR)/files/etc
digiges-gl-ar150-speedtest: digiges-update-feeds digiges-configure-gl-ar150-speedtest defconfig world
.PHONY: digiges-configure-gl-ar150-speedtest digiges-gl-ar150-speedtest

digiges-configure-gl-ar300m-tor: digiges-configure-tor
	cat $(TOPDIR)/digiges-config/base-gl-ar300m >> $(TOPDIR)/.config
	cp $(TOPDIR)/digiges-files/gl-ar300m-tor/etc/config/wireless $(TOPDIR)/files/etc/config
digiges-gl-ar300m-tor: digiges-update-feeds digiges-configure-gl-ar300m-tor defconfig world
.PHONY: digiges-configure-gl-ar300m-tor digiges-gl-ar300m-tor

digiges-configure-gl-ar300m-speedtest: digiges-configure-gl-ar300m-tor
	cp -r $(TOPDIR)/digiges-files/iperf3-on-startup/etc/init.d $(TOPDIR)/files/etc
digiges-gl-ar300m-speedtest: digiges-update-feeds digiges-configure-gl-ar300m-speedtest defconfig world
.PHONY: digiges-configure-gl-ar300m-speedtest digiges-gl-ar300m-speedtest
