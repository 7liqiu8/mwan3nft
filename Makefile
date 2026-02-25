# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2024 mwan3nft

include $(TOPDIR)/rules.mk

PKG_NAME:=mwan3nft
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=mwan3nft

include $(INCLUDE_DIR)/package.mk

define Package/mwan3nft
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Routing and Redirection
  TITLE:=Multiwan manager for nftables
  DEPENDS:=+nftables +ip-full +jshn
  PKGARCH:=all
endef

define Package/mwan3nft/description
  Multi-WAN load balancing and failover manager using nftables.
  Compatible with OpenClash, Lucky and other applications.
endef

define Package/mwan3nft/conffiles
/etc/config/mwan3nft
endef

define Build/Compile
endef

define Package/mwan3nft/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/mwan3nft $(1)/etc/config/mwan3nft
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/mwan3nft $(1)/etc/init.d/mwan3nft
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_DATA) ./files/etc/hotplug.d/iface/15-mwan3nft $(1)/etc/hotplug.d/iface/15-mwan3nft
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/mwan3nft $(1)/usr/sbin/mwan3nft
	$(INSTALL_BIN) ./files/usr/sbin/mwan3nft-track $(1)/usr/sbin/mwan3nft-track
	$(INSTALL_DIR) $(1)/usr/lib/mwan3nft
	$(INSTALL_DATA) ./files/usr/lib/mwan3nft/common.sh $(1)/usr/lib/mwan3nft/common.sh
	$(INSTALL_DATA) ./files/usr/lib/mwan3nft/nft.sh $(1)/usr/lib/mwan3nft/nft.sh
	$(INSTALL_DATA) ./files/usr/lib/mwan3nft/policy.sh $(1)/usr/lib/mwan3nft/policy.sh
	# Fix Windows CRLF line endings
	$(SED) 's/\r$$//' $(1)/usr/sbin/mwan3nft
	$(SED) 's/\r$$//' $(1)/usr/sbin/mwan3nft-track
	$(SED) 's/\r$$//' $(1)/etc/init.d/mwan3nft
	$(SED) 's/\r$$//' $(1)/etc/hotplug.d/iface/15-mwan3nft
	$(SED) 's/\r$$//' $(1)/usr/lib/mwan3nft/common.sh
	$(SED) 's/\r$$//' $(1)/usr/lib/mwan3nft/nft.sh
	$(SED) 's/\r$$//' $(1)/usr/lib/mwan3nft/policy.sh
	$(SED) 's/\r$$//' $(1)/etc/config/mwan3nft
endef

$(eval $(call BuildPackage,mwan3nft))
