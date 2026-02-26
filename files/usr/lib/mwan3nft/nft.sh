#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# mwan3nft nftables rule management

# NFT table and chain names
NFT_TABLE="mwan3nft"
NFT_FAMILY="inet"

# Initialize nftables structure
mwan3nft_nft_init() {
	mwan3nft_log "info" "Initializing nftables rules"

	# Create main table
	nft add table $NFT_FAMILY $NFT_TABLE 2>/dev/null

	# Create chains
	# prerouting chain for incoming traffic marking
	nft add chain $NFT_FAMILY $NFT_TABLE prerouting \
		"{ type filter hook prerouting priority mangle - 1; policy accept; }" 2>/dev/null

	# output chain for locally generated traffic
	nft add chain $NFT_FAMILY $NFT_TABLE output \
		"{ type route hook output priority mangle - 1; policy accept; }" 2>/dev/null

	# postrouting chain for connection tracking restore
	nft add chain $NFT_FAMILY $NFT_TABLE postrouting \
		"{ type filter hook postrouting priority mangle - 1; policy accept; }" 2>/dev/null

	# Create helper chains
	nft add chain $NFT_FAMILY $NFT_TABLE mwan3_mark 2>/dev/null
	nft add chain $NFT_FAMILY $NFT_TABLE mwan3_rules 2>/dev/null
	nft add chain $NFT_FAMILY $NFT_TABLE mwan3_policy 2>/dev/null
	nft add chain $NFT_FAMILY $NFT_TABLE mwan3_connected 2>/dev/null

	# Create sets for sticky sessions (connection tracking)
	nft add set $NFT_FAMILY $NFT_TABLE mwan3_sticky \
		"{ type ipv4_addr . ipv4_addr . inet_proto . inet_service . inet_service; flags timeout; timeout 600s; }" 2>/dev/null

	# Create map for interface marks
	nft add map $NFT_FAMILY $NFT_TABLE iface_mark \
		"{ type ifname : mark; }" 2>/dev/null

	# Build initial rules
	mwan3nft_nft_build_rules
}

# Cleanup nftables rules
mwan3nft_nft_cleanup() {
	mwan3nft_log "info" "Cleaning up nftables rules"

	nft delete table $NFT_FAMILY $NFT_TABLE 2>/dev/null
}

# Reload nftables rules
mwan3nft_nft_reload() {
	mwan3nft_log "info" "Reloading nftables rules"

	# Flush existing rules but keep table structure
	nft flush chain $NFT_FAMILY $NFT_TABLE prerouting 2>/dev/null
	nft flush chain $NFT_FAMILY $NFT_TABLE output 2>/dev/null
	nft flush chain $NFT_FAMILY $NFT_TABLE postrouting 2>/dev/null
	nft flush chain $NFT_FAMILY $NFT_TABLE mwan3_mark 2>/dev/null
	nft flush chain $NFT_FAMILY $NFT_TABLE mwan3_rules 2>/dev/null
	nft flush chain $NFT_FAMILY $NFT_TABLE mwan3_policy 2>/dev/null
	nft flush chain $NFT_FAMILY $NFT_TABLE mwan3_connected 2>/dev/null

	# Rebuild rules
	mwan3nft_nft_build_rules
}

# Build all nftables rules
mwan3nft_nft_build_rules() {
	local mask

	mask=$(mwan3nft_get_fwmark_mask)

	# === PREROUTING CHAIN ===
	# Skip traffic that already has a mark (from OpenClash, Lucky, etc.)
	nft add rule $NFT_FAMILY $NFT_TABLE prerouting \
		"meta mark & $mask != 0 accept"

	# Skip local/loopback traffic
	nft add rule $NFT_FAMILY $NFT_TABLE prerouting \
		"iif lo accept"

	# Restore mark from conntrack for established connections (sticky sessions)
	nft add rule $NFT_FAMILY $NFT_TABLE prerouting \
		"ct state established,related meta mark set ct mark & $mask accept"

	# Jump to rules chain for new connections
	nft add rule $NFT_FAMILY $NFT_TABLE prerouting \
		"ct state new jump mwan3_rules"

	# === OUTPUT CHAIN ===
	# Skip traffic that already has a mark
	nft add rule $NFT_FAMILY $NFT_TABLE output \
		"meta mark & $mask != 0 accept"

	# Skip local/loopback traffic
	nft add rule $NFT_FAMILY $NFT_TABLE output \
		"oif lo accept"

	# Restore mark from conntrack for established connections
	nft add rule $NFT_FAMILY $NFT_TABLE output \
		"ct state established,related meta mark set ct mark & $mask accept"

	# Jump to rules chain for new connections
	nft add rule $NFT_FAMILY $NFT_TABLE output \
		"ct state new jump mwan3_rules"

	# === POSTROUTING CHAIN ===
	# Save mark to conntrack for sticky sessions
	nft add rule $NFT_FAMILY $NFT_TABLE postrouting \
		"meta mark & $mask != 0 ct mark set meta mark & $mask"

	# === MWAN3_RULES CHAIN ===
	# Build rules from configuration
	mwan3nft_nft_build_user_rules

	# === MWAN3_CONNECTED CHAIN ===
	# Skip traffic to directly connected networks
	mwan3nft_nft_build_connected_rules

	# === Update interface marks ===
	mwan3nft_nft_update_iface_marks
}

# Build user-defined rules
mwan3nft_nft_build_user_rules() {
	config_foreach mwan3nft_nft_add_rule rule
}

# Add a single rule
mwan3nft_nft_add_rule() {
	local rule="$1"
	local src_ip dest_ip src_port dest_port proto use_policy family sticky
	local nft_rule=""

	config_get src_ip "$rule" src_ip ""
	config_get dest_ip "$rule" dest_ip ""
	config_get src_port "$rule" src_port ""
	config_get dest_port "$rule" dest_port ""
	config_get proto "$rule" proto ""
	config_get use_policy "$rule" use_policy ""
	config_get family "$rule" family "ipv4"
	config_get sticky "$rule" sticky "0"

	# Skip if no policy defined
	[ -z "$use_policy" ] && return

	# Handle "default" policy - skip mwan3nft processing
	[ "$use_policy" = "default" ] && {
		mwan3nft_nft_add_skip_rule "$rule" "$src_ip" "$dest_ip" "$src_port" "$dest_port" "$proto" "$family"
		return
	}

	# Build match conditions
	nft_rule=""

	# Family filter
	if [ "$family" = "ipv4" ]; then
		nft_rule="ip version 4"
	elif [ "$family" = "ipv6" ]; then
		nft_rule="ip6 version 6"
	fi

	# Source IP
	if [ -n "$src_ip" ]; then
		local src_set
		src_set=$(mwan3nft_ip_to_nft_set "$src_ip")
		if [ "$family" = "ipv6" ]; then
			nft_rule="$nft_rule ip6 saddr $src_set"
		else
			nft_rule="$nft_rule ip saddr $src_set"
		fi
	fi

	# Destination IP
	if [ -n "$dest_ip" ]; then
		local dest_set
		dest_set=$(mwan3nft_ip_to_nft_set "$dest_ip")
		if [ "$family" = "ipv6" ]; then
			nft_rule="$nft_rule ip6 daddr $dest_set"
		else
			nft_rule="$nft_rule ip daddr $dest_set"
		fi
	fi

	# Protocol (empty or "all" means match all protocols)
	if [ -n "$proto" ] && [ "$proto" != "all" ]; then
		nft_rule="$nft_rule meta l4proto { $proto }"
	fi

	# Source port (requires protocol)
	if [ -n "$src_port" ]; then
		local sport_set
		sport_set=$(mwan3nft_port_to_nft_set "$src_port")
		nft_rule="$nft_rule th sport $sport_set"
	fi

	# Destination port (requires protocol)
	if [ -n "$dest_port" ]; then
		local dport_set
		dport_set=$(mwan3nft_port_to_nft_set "$dest_port")
		nft_rule="$nft_rule th dport $dport_set"
	fi

	# Add policy jump
	nft_rule="$nft_rule jump mwan3_policy_${use_policy}"

	# Add the rule
	nft add rule $NFT_FAMILY $NFT_TABLE mwan3_rules $nft_rule 2>/dev/null

	mwan3nft_log "debug" "Added rule: $rule -> policy $use_policy"
}

# Add skip rule for "default" policy
mwan3nft_nft_add_skip_rule() {
	local rule="$1"
	local src_ip="$2"
	local dest_ip="$3"
	local src_port="$4"
	local dest_port="$5"
	local proto="$6"
	local family="$7"
	local nft_rule=""

	# Build match conditions (same as above)
	if [ "$family" = "ipv4" ]; then
		nft_rule="ip version 4"
	elif [ "$family" = "ipv6" ]; then
		nft_rule="ip6 version 6"
	fi

	if [ -n "$src_ip" ]; then
		local src_set
		src_set=$(mwan3nft_ip_to_nft_set "$src_ip")
		if [ "$family" = "ipv6" ]; then
			nft_rule="$nft_rule ip6 saddr $src_set"
		else
			nft_rule="$nft_rule ip saddr $src_set"
		fi
	fi

	if [ -n "$dest_ip" ]; then
		local dest_set
		dest_set=$(mwan3nft_ip_to_nft_set "$dest_ip")
		if [ "$family" = "ipv6" ]; then
			nft_rule="$nft_rule ip6 daddr $dest_set"
		else
			nft_rule="$nft_rule ip daddr $dest_set"
		fi
	fi

	if [ -n "$proto" ] && [ "$proto" != "all" ]; then
		nft_rule="$nft_rule meta l4proto { $proto }"
	fi

	if [ -n "$src_port" ]; then
		local sport_set
		sport_set=$(mwan3nft_port_to_nft_set "$src_port")
		nft_rule="$nft_rule th sport $sport_set"
	fi

	if [ -n "$dest_port" ]; then
		local dport_set
		dport_set=$(mwan3nft_port_to_nft_set "$dest_port")
		nft_rule="$nft_rule th dport $dport_set"
	fi

	# Accept (skip mwan3nft processing)
	nft_rule="$nft_rule accept"

	nft add rule $NFT_FAMILY $NFT_TABLE mwan3_rules $nft_rule 2>/dev/null

	mwan3nft_log "debug" "Added skip rule: $rule"
}

# Build connected networks rules (skip local traffic)
mwan3nft_nft_build_connected_rules() {
	local local_source

	config_get local_source globals local_source "lan"

	# Skip traffic from local networks
	# This prevents mwan3nft from affecting LAN-to-LAN traffic

	# Add common private networks
	nft add rule $NFT_FAMILY $NFT_TABLE mwan3_connected \
		"ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8 } accept" 2>/dev/null

	# Add IPv6 local addresses
	nft add rule $NFT_FAMILY $NFT_TABLE mwan3_connected \
		"ip6 daddr { ::1/128, fe80::/10, fc00::/7 } accept" 2>/dev/null
}

# Update interface marks in the map
mwan3nft_nft_update_iface_marks() {
	# Clear existing map entries
	nft flush map $NFT_FAMILY $NFT_TABLE iface_mark 2>/dev/null

	# Add marks for each enabled interface
	config_foreach mwan3nft_nft_add_iface_mark interface
}

# Add interface mark to map
mwan3nft_nft_add_iface_mark() {
	local iface="$1"
	local enabled device fwmark

	config_get enabled "$iface" enabled 0
	[ "$enabled" = "0" ] && return

	network_get_device device "$iface"
	[ -z "$device" ] && return

	fwmark=$(mwan3nft_get_fwmark "$iface")

	nft add element $NFT_FAMILY $NFT_TABLE iface_mark \
		"{ $device : $fwmark }" 2>/dev/null

	mwan3nft_log "debug" "Added interface mark: $iface ($device) -> $fwmark"
}

# Update interface status in nftables
mwan3nft_nft_update_interface() {
	local iface="$1"
	local status="$2"

	mwan3nft_log "info" "Updating nftables for interface $iface: $status"

	# Rebuild policy chains to reflect new interface status
	mwan3nft_nft_rebuild_policies
}

# Refresh interface rules
mwan3nft_nft_refresh_interface() {
	local iface="$1"

	mwan3nft_log "info" "Refreshing nftables for interface $iface"

	# Update interface mark
	mwan3nft_nft_update_iface_marks

	# Rebuild policies
	mwan3nft_nft_rebuild_policies
}

# Rebuild all policy chains
mwan3nft_nft_rebuild_policies() {
	# Remove existing policy chains
	local chains
	chains=$(nft list chains $NFT_FAMILY $NFT_TABLE 2>/dev/null | grep "mwan3_policy_" | awk '{print $2}')

	for chain in $chains; do
		nft delete chain $NFT_FAMILY $NFT_TABLE "$chain" 2>/dev/null
	done

	# Rebuild policy chains
	config_foreach mwan3nft_nft_build_policy policy
}

# Build a policy chain
mwan3nft_nft_build_policy() {
	local policy="$1"
	local last_resort
	local chain_name="mwan3_policy_${policy}"
	local members=""
	local online_members=""
	local total_weight=0

	config_get last_resort "$policy" last_resort "default"

	# Create policy chain
	nft add chain $NFT_FAMILY $NFT_TABLE "$chain_name" 2>/dev/null

	# Collect online members and their weights
	collect_member() {
		local member="$1"
		local iface metric weight

		iface=$(mwan3nft_get_member_iface "$member")
		metric=$(mwan3nft_get_member_metric "$member")
		weight=$(mwan3nft_get_member_weight "$member")

		# Check if interface is online
		if mwan3nft_iface_is_online "$iface"; then
			online_members="${online_members}${online_members:+ }${member}:${iface}:${metric}:${weight}"
			total_weight=$((total_weight + weight))
		fi
	}

	config_list_foreach "$policy" use_member collect_member

	# If no online members, use last_resort
	if [ -z "$online_members" ]; then
		case "$last_resort" in
			unreachable)
				nft add rule $NFT_FAMILY $NFT_TABLE "$chain_name" \
					"reject with icmp type host-unreachable" 2>/dev/null
				;;
			blackhole)
				nft add rule $NFT_FAMILY $NFT_TABLE "$chain_name" \
					"drop" 2>/dev/null
				;;
			*)
				# default - let system routing handle it
				nft add rule $NFT_FAMILY $NFT_TABLE "$chain_name" \
					"accept" 2>/dev/null
				;;
		esac
		return
	fi

	# Build load balancing rules based on weights
	# Group members by metric (lower metric = higher priority)
	local current_metric=0
	local metric_members=""

	# Sort by metric and build rules
	for entry in $(echo "$online_members" | tr ' ' '\n' | sort -t: -k3 -n); do
		local member iface metric weight
		member=$(echo "$entry" | cut -d: -f1)
		iface=$(echo "$entry" | cut -d: -f2)
		metric=$(echo "$entry" | cut -d: -f3)
		weight=$(echo "$entry" | cut -d: -f4)

		if [ "$metric" != "$current_metric" ] && [ -n "$metric_members" ]; then
			# Build rules for previous metric group
			mwan3nft_nft_build_lb_rules "$chain_name" "$metric_members"
			metric_members=""
		fi

		current_metric="$metric"
		metric_members="${metric_members}${metric_members:+ }${iface}:${weight}"
	done

	# Build rules for last metric group
	if [ -n "$metric_members" ]; then
		mwan3nft_nft_build_lb_rules "$chain_name" "$metric_members"
	fi
}

# Build load balancing rules for a group of interfaces
mwan3nft_nft_build_lb_rules() {
	local chain="$1"
	local members="$2"
	local total_weight=0
	local iface weight fwmark

	# Calculate total weight
	for entry in $members; do
		weight=$(echo "$entry" | cut -d: -f2)
		total_weight=$((total_weight + weight))
	done

	# If only one member, simple mark
	local member_count
	member_count=$(echo "$members" | wc -w)

	if [ "$member_count" -eq 1 ]; then
		iface=$(echo "$members" | cut -d: -f1)
		fwmark=$(mwan3nft_get_fwmark "$iface")

		nft add rule $NFT_FAMILY $NFT_TABLE "$chain" \
			"meta mark set $fwmark accept" 2>/dev/null
		return
	fi

	# Multiple members - use sequential probability rules
	# Each rule uses its own numgen call with adjusted probability
	# so that the overall distribution matches the weights.
	#
	# Example: weights 3, 5, 2 (total=10)
	#   Rule 1: numgen random mod 10 < 3  → 30% → iface1, accept
	#   Rule 2: numgen random mod 7 < 5   → ~71% of remaining 70% = 50% → iface2, accept
	#   Rule 3: fallback → iface3, accept (remaining 20%)
	local remaining=$total_weight
	local is_last=0
	local count=0

	for entry in $members; do
		iface=$(echo "$entry" | cut -d: -f1)
		weight=$(echo "$entry" | cut -d: -f2)
		fwmark=$(mwan3nft_get_fwmark "$iface")
		count=$((count + 1))

		if [ "$count" -eq "$member_count" ]; then
			# Last member - fallback rule (no probability check needed)
			nft add rule $NFT_FAMILY $NFT_TABLE "$chain" \
				"meta mark set $fwmark accept" 2>/dev/null
		else
			# Use numgen with adjusted probability against remaining weight
			nft add rule $NFT_FAMILY $NFT_TABLE "$chain" \
				"numgen random mod $remaining < $weight meta mark set $fwmark accept" 2>/dev/null
			remaining=$((remaining - weight))
		fi
	done
}
