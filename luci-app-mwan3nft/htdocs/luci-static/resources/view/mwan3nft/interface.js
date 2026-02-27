'use strict';
'require view';
'require form';
'require uci';
'require network';

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('mwan3nft'),
			network.getWANNetworks()
		]);
	},

	render: function(data) {
		var m, s, o;
		var wanNetworks = data[1] || [];

		m = new form.Map('mwan3nft', _('MultiWAN NFT - Interfaces'),
			_('Configure WAN interfaces for multi-WAN load balancing and failover.'));

		// Global settings
		s = m.section(form.NamedSection, 'globals', 'globals', _('Global Settings'));
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.rmempty = false;
		o.default = '1';

		o = s.option(form.Value, 'mmx_mask', _('Firewall Mark Mask'),
			_('Firewall mark mask used for policy routing. Default: 0x3F00'));
		o.default = '0x3F00';
		o.rmempty = false;

		o = s.option(form.Value, 'local_source', _('Local Source Interface'),
			_('Interface for local traffic. Usually lan.'));
		o.default = 'lan';

		// Interface configuration
		s = m.section(form.TypedSection, 'interface', _('Interfaces'));
		s.addremove = true;
		s.anonymous = false;
		s.addbtntitle = _('Add Interface');

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.rmempty = false;
		o.default = '1';

		o = s.option(form.ListValue, 'family', _('Address Family'));
		o.value('ipv4', _('IPv4'));
		o.value('ipv6', _('IPv6'));
		o.value('both', _('IPv4 and IPv6'));
		o.default = 'ipv4';

		o = s.option(form.DynamicList, 'track_ip', _('Tracking IP'),
			_('IP addresses to ping for health checking. Space separated.'));
		o.datatype = 'ipaddr';
		o.default = '223.5.5.5';

		o = s.option(form.ListValue, 'track_method', _('Tracking Method'));
		o.value('ping', _('Ping'));
		o.value('arping', _('Arping'));
		o.value('httping', _('HTTP'));
		o.default = 'ping';

		o = s.option(form.Value, 'reliability', _('Reliability'),
			_('Number of successful checks required to consider interface online.'));
		o.datatype = 'uinteger';
		o.default = '2';

		o = s.option(form.Value, 'count', _('Ping Count'),
			_('Number of ping packets to send per check.'));
		o.datatype = 'uinteger';
		o.default = '1';

		o = s.option(form.Value, 'size', _('Ping Size'),
			_('Size of ping packets in bytes.'));
		o.datatype = 'uinteger';
		o.default = '56';

		o = s.option(form.Value, 'max_ttl', _('Max TTL'),
			_('Maximum time to live for ping packets.'));
		o.datatype = 'uinteger';
		o.default = '60';

		o = s.option(form.Value, 'timeout', _('Timeout'),
			_('Timeout in seconds for each ping.'));
		o.datatype = 'uinteger';
		o.default = '4';

		o = s.option(form.Value, 'interval', _('Check Interval'),
			_('Interval in seconds between health checks when online.'));
		o.datatype = 'uinteger';
		o.default = '10';

		o = s.option(form.Value, 'failure_interval', _('Failure Interval'),
			_('Interval in seconds between checks when failing.'));
		o.datatype = 'uinteger';
		o.default = '5';

		o = s.option(form.Value, 'recovery_interval', _('Recovery Interval'),
			_('Interval in seconds between checks when recovering.'));
		o.datatype = 'uinteger';
		o.default = '5';

		o = s.option(form.Value, 'down', _('Down Count'),
			_('Number of failed checks before marking interface offline.'));
		o.datatype = 'uinteger';
		o.default = '5';

		o = s.option(form.Value, 'up', _('Up Count'),
			_('Number of successful checks before marking interface online.'));
		o.datatype = 'uinteger';
		o.default = '5';

		o = s.option(form.ListValue, 'initial_state', _('Initial State'),
			_('Initial state of interface when service starts.'));
		o.value('online', _('Online'));
		o.value('offline', _('Offline'));
		o.default = 'online';

		return m.render();
	}
});
