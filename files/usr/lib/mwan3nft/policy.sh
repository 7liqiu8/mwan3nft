#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# mwan3nft policy routing management

# RT_TABLES file
RT_TABLES_FILE="/etc/iproute2/rt_tables"

# Initialize routing tables and rules
mwan3nft_policy_init() {
	mwan3nft_log "info" "Initializing routing policies"

	# Ensure rt_tables file exists
	[ -f "$RT_TABLES_FILE" ] || {
		mkdir -p "$(dirname $RT_TABLES_FILE)"
		cat > "$RT_TABLES_FILE" <<EOF
#
# reserved values
#
255	local
254	main
253	default
0	unspec
#
# local
#
EOF
	}

	# Setup routing tables for each interface
	config_foreach mwan3nft_policy_setup_interface interface

	# Setup ip rules for fwmark routing
	mwan3nft_policy_setup_rules
}

# Cleanup routing tables and rules
mwan3nft_policy_cleanup() {
	mwan3nft_log "info" "Cleaning up routing policies"

	# Remove ip rules
	config_foreach mwan3nft_policy_cleanup_interface interface

	# Flush routing tables
	config_foreach mwan3nft_policy_flush_table interface
}

# Reload routing policies
mwan3nft_policy_reload() {
	mwan3nft_log "info" "Reloading routing policies"

	# Cleanup and reinitialize
	mwan3nft_policy_cleanup
	mwan3nft_policy_init
}

# Setup routing for a single interface
mwan3nft_policy_setup_interface() {
	local iface="$1"
	local enabled family table_id device gateway ipaddr

	config_get enabled "$iface" enabled 0
	[ "$enabled" = "0" ] && return

	config_get family "$iface" family "ipv4"

	table_id=$(mwan3nft_get_table_id "$iface")

	# Add to rt_tables if not exists
	grep -q "^$table_id[[:space:]]" "$RT_TABLES_FILE" || {
		echo "$table_id	mwan3_$iface" >> "$RT_TABLES_FILE"
	}

	# Get interface info
	network_get_device device "$iface"
	network_get_gateway gateway "$iface"
	network_get_ipaddr ipaddr "$iface"

	[ -z "$device" ] && {
		mwan3nft_log "debug" "Interface $iface has no device yet"
		return
	}

	# Flush existing routes in table
	ip route flush table "$table_id" 2>/dev/null

	# Add default route via gateway
	if [ -n "$gateway" ]; then
		if [ "$family" = "ipv6" ]; then
			ip -6 route add default via "$gateway" dev "$device" table "$table_id" 2>/dev/null
		else
			ip -4 route add default via "$gateway" dev "$device" table "$table_id" 2>/dev/null
		fi
		mwan3nft_log "debug" "Added default route for $iface via $gateway"
	fi

	# Add connected route
	if [ -n "$ipaddr" ]; then
		local network
		network=$(ip -4 route show dev "$device" scope link 2>/dev/null | head -1 | awk '{print $1}')
		if [ -n "$network" ]; then
			ip -4 route add "$network" dev "$device" scope link table "$table_id" 2>/dev/null
		fi
	fi

	mwan3nft_log "info" "Setup routing table $table_id for interface $iface"
}

# Cleanup routing for a single interface
mwan3nft_policy_cleanup_interface() {
	local iface="$1"
	local table_id fwmark mask

	table_id=$(mwan3nft_get_table_id "$iface")
	fwmark=$(mwan3nft_get_fwmark "$iface")
	mask=$(mwan3nft_get_fwmark_mask)

	# Remove ip rules for this interface
	while ip rule del fwmark "$fwmark/$mask" table "$table_id" 2>/dev/null; do :; done
	while ip -6 rule del fwmark "$fwmark/$mask" table "$table_id" 2>/dev/null; do :; done

	mwan3nft_log "debug" "Cleaned up rules for interface $iface"
}

# Flush routing table for interface
mwan3nft_policy_flush_table() {
	local iface="$1"
	local table_id

	table_id=$(mwan3nft_get_table_id "$iface")

	ip route flush table "$table_id" 2>/dev/null
	ip -6 route flush table "$table_id" 2>/dev/null

	mwan3nft_log "debug" "Flushed routing table $table_id for interface $iface"
}

# Setup ip rules for fwmark-based routing
mwan3nft_policy_setup_rules() {
	config_foreach mwan3nft_policy_add_rule interface
}

# Add ip rule for interface
mwan3nft_policy_add_rule() {
	local iface="$1"
	local enabled family table_id fwmark mask

	config_get enabled "$iface" enabled 0
	[ "$enabled" = "0" ] && return

	config_get family "$iface" family "ipv4"

	table_id=$(mwan3nft_get_table_id "$iface")
	fwmark=$(mwan3nft_get_fwmark "$iface")
	mask=$(mwan3nft_get_fwmark_mask)

	# Remove existing rules first
	while ip rule del fwmark "$fwmark/$mask" table "$table_id" 2>/dev/null; do :; done
	while ip -6 rule del fwmark "$fwmark/$mask" table "$table_id" 2>/dev/null; do :; done

	# Add new rules
	# Priority 1000 + table_id to ensure proper ordering
	local priority=$((1000 + table_id))

	if [ "$family" = "ipv4" ] || [ "$family" = "both" ]; then
		ip -4 rule add fwmark "$fwmark/$mask" table "$table_id" priority "$priority" 2>/dev/null
	fi

	if [ "$family" = "ipv6" ] || [ "$family" = "both" ]; then
		ip -6 rule add fwmark "$fwmark/$mask" table "$table_id" priority "$priority" 2>/dev/null
	fi

	mwan3nft_log "debug" "Added ip rule: fwmark $fwmark/$mask -> table $table_id (priority $priority)"
}

# Update interface routing when status changes
mwan3nft_policy_update_interface() {
	local iface="$1"
	local status="$2"

	mwan3nft_log "info" "Updating routing for interface $iface: $status"

	if [ "$status" = "online" ]; then
		# Interface came online, setup routing
		mwan3nft_policy_setup_interface "$iface"
		mwan3nft_policy_add_rule "$iface"
	else
		# Interface went offline, keep rules but routes will fail
		# This allows quick recovery when interface comes back
		mwan3nft_log "debug" "Interface $iface offline, keeping rules"
	fi
}

# Refresh interface routing (e.g., IP changed)
mwan3nft_policy_refresh_interface() {
	local iface="$1"

	mwan3nft_log "info" "Refreshing routing for interface $iface"

	# Re-setup routing table
	mwan3nft_policy_setup_interface "$iface"
}

# Force a policy to use specific interface
mwan3nft_policy_force_interface() {
	local policy="$1"
	local iface="$2"

	mwan3nft_log "info" "Forcing policy $policy to use interface $iface"

	# This is handled by nftables rules
	# Just trigger a rebuild of the policy chain
	mwan3nft_nft_rebuild_policies
}

# Get routing table info for interface
mwan3nft_policy_get_table_info() {
	local iface="$1"
	local table_id

	table_id=$(mwan3nft_get_table_id "$iface")

	echo "Routing table $table_id (mwan3_$iface):"
	ip route show table "$table_id" 2>/dev/null
}

# Show all routing tables
mwan3nft_policy_show_tables() {
	echo "mwan3nft Routing Tables:"
	echo "========================"

	config_foreach show_table interface
}

show_table() {
	local iface="$1"
	local enabled table_id

	config_get enabled "$iface" enabled 0
	[ "$enabled" = "0" ] && return

	table_id=$(mwan3nft_get_table_id "$iface")

	echo ""
	echo "Interface: $iface (table $table_id)"
	echo "-----------------------------------"
	ip route show table "$table_id" 2>/dev/null || echo "  (empty)"
}

# Show ip rules
mwan3nft_policy_show_rules() {
	echo "mwan3nft IP Rules:"
	echo "=================="
	echo ""
	echo "IPv4 Rules:"
	ip -4 rule show | grep -E "fwmark|mwan3"
	echo ""
	echo "IPv6 Rules:"
	ip -6 rule show | grep -E "fwmark|mwan3"
}

# Verify routing is working
mwan3nft_policy_verify() {
	local iface="$1"
	local table_id gateway device

	table_id=$(mwan3nft_get_table_id "$iface")

	network_get_gateway gateway "$iface"
	network_get_device device "$iface"

	[ -z "$gateway" ] || [ -z "$device" ] && {
		echo "Interface $iface: NOT READY (no gateway or device)"
		return 1
	}

	# Check if route exists
	if ip route show table "$table_id" | grep -q "default"; then
		echo "Interface $iface: OK (table $table_id has default route)"
		return 0
	else
		echo "Interface $iface: ERROR (no default route in table $table_id)"
		return 1
	fi
}
