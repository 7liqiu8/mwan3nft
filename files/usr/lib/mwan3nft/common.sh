#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# mwan3nft common functions

MWAN3NFT_STATUS_DIR="/var/run/mwan3nft"
MWAN3NFT_LOG_TAG="mwan3nft"

# Logging function
mwan3nft_log() {
	local level="$1"
	local message="$2"

	logger -t "$MWAN3NFT_LOG_TAG" -p "daemon.$level" "$message"
}

# Get interface status
mwan3nft_get_iface_status() {
	local iface="$1"
	local status_file="${MWAN3NFT_STATUS_DIR}/${iface}.status"

	if [ -f "$status_file" ]; then
		cat "$status_file"
	else
		echo "unknown"
	fi
}

# Set interface status
mwan3nft_set_iface_status() {
	local iface="$1"
	local status="$2"

	mkdir -p "$MWAN3NFT_STATUS_DIR"
	echo "$status" > "${MWAN3NFT_STATUS_DIR}/${iface}.status"
}

# Check if interface is online
mwan3nft_iface_is_online() {
	local iface="$1"
	local status

	status=$(mwan3nft_get_iface_status "$iface")
	[ "$status" = "online" ]
}

# Get list of online interfaces
mwan3nft_get_online_ifaces() {
	local ifaces=""
	local iface status

	for status_file in "${MWAN3NFT_STATUS_DIR}"/*.status; do
		[ -f "$status_file" ] || continue
		iface=$(basename "$status_file" .status)
		status=$(cat "$status_file")
		[ "$status" = "online" ] && ifaces="${ifaces}${ifaces:+ }${iface}"
	done

	echo "$ifaces"
}

# Get routing table ID for interface
# Uses a pure-shell hash of interface name to generate consistent table ID
# No external tools needed (cksum is not available on OpenWrt)
mwan3nft_get_table_id() {
	local iface="$1"
	local hash=0
	local tmp="$iface"
	local c

	# Simple DJB2-like hash in pure shell
	while [ -n "$tmp" ]; do
		c="${tmp%"${tmp#?}"}"
		tmp="${tmp#?}"
		hash=$(( (hash * 33 + $(printf '%d' "'$c")) % 65536 ))
	done

	# Map to range 100-199
	echo $((100 + (hash % 100)))
}

# Get fwmark for interface
mwan3nft_get_fwmark() {
	local iface="$1"
	local table_id

	table_id=$(mwan3nft_get_table_id "$iface")
	# Use table_id shifted left by 8 bits as fwmark
	echo "0x$( printf '%x' $((table_id << 8)) )"
}

# Get fwmark mask from globals
mwan3nft_get_fwmark_mask() {
	local mask

	config_get mask globals mmx_mask "0x3F00"
	echo "$mask"
}

# Check if a value is in a list
mwan3nft_in_list() {
	local value="$1"
	local list="$2"
	local item

	for item in $list; do
		[ "$item" = "$value" ] && return 0
	done

	return 1
}

# Get member interface
mwan3nft_get_member_iface() {
	local member="$1"
	local iface

	config_get iface "$member" interface
	echo "$iface"
}

# Get member metric
mwan3nft_get_member_metric() {
	local member="$1"
	local metric

	config_get metric "$member" metric 1
	echo "$metric"
}

# Get member weight
mwan3nft_get_member_weight() {
	local member="$1"
	local weight

	config_get weight "$member" weight 1
	echo "$weight"
}

# Parse IP address list (space or comma separated)
mwan3nft_parse_ip_list() {
	local list="$1"

	echo "$list" | tr ',' ' ' | tr -s ' '
}

# Parse port list (space or comma separated)
mwan3nft_parse_port_list() {
	local list="$1"

	echo "$list" | tr ',' ' ' | tr -s ' '
}

# Convert IP list to nftables set format
mwan3nft_ip_to_nft_set() {
	local ips="$1"
	local result=""
	local ip

	for ip in $(mwan3nft_parse_ip_list "$ips"); do
		result="${result}${result:+, }${ip}"
	done

	echo "{ $result }"
}

# Convert port list to nftables set format
# Supports: single port (80), range (607-3000), comma/space separated (80,443,8080)
mwan3nft_port_to_nft_set() {
	local ports="$1"
	local result=""
	local port

	# Normalize: replace commas with spaces
	for port in $(echo "$ports" | tr ',' ' '); do
		# nftables uses - for ranges natively, so 607-3000 works as-is
		result="${result}${result:+, }${port}"
	done

	# Single entry doesn't need braces in nftables
	if echo "$result" | grep -q ","; then
		echo "{ $result }"
	else
		echo "$result"
	fi
}

# Check if running on OpenWrt
mwan3nft_is_openwrt() {
	[ -f /etc/openwrt_release ]
}

# Get OpenWrt version
mwan3nft_get_openwrt_version() {
	if [ -f /etc/openwrt_release ]; then
		. /etc/openwrt_release
		echo "$DISTRIB_RELEASE"
	else
		echo "unknown"
	fi
}
