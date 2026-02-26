'use strict';
'require view';
'require form';
'require uci';

return view.extend({
	load: function() {
		return uci.load('mwan3nft');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('mwan3nft', _('MultiWAN NFT - Rules'),
			_('Rules match traffic and apply policies. Rules are processed in order.'));

		s = m.section(form.TypedSection, 'rule', _('Rules'));
		s.addremove = true;
		s.anonymous = false;
		s.sortable = true;
		s.addbtntitle = _('Add Rule');

		s.tab('general', _('General'));
		s.tab('advanced', _('Advanced'));

		// General tab
		o = s.taboption('general', form.ListValue, 'use_policy', _('Policy'),
			_('Select the policy to apply for matching traffic.'));
		o.rmempty = false;
		o.value('default', _('Use default routing (bypass mwan3nft)'));

		// Populate policy list from config
		uci.sections('mwan3nft', 'policy', function(section) {
			o.value(section['.name'], section['.name']);
		});

		o = s.taboption('general', form.ListValue, 'family', _('Address Family'));
		o.value('ipv4', _('IPv4'));
		o.value('ipv6', _('IPv6'));
		o.default = 'ipv4';

		o = s.taboption('general', form.Value, 'src_ip', _('Source IP'),
			_('Match source IP address or CIDR. Space separated for multiple.'));
		o.datatype = 'list(neg(ipmask))';
		o.placeholder = '192.168.1.0/24';

		o = s.taboption('general', form.Value, 'dest_ip', _('Destination IP'),
			_('Match destination IP address or CIDR. Space separated for multiple.'));
		o.datatype = 'list(neg(ipmask))';
		o.placeholder = '0.0.0.0/0';

		o = s.taboption('general', form.ListValue, 'proto', _('Protocol'),
			_('Match protocol. Leave empty or select "all" to match all protocols.'));
		o.value('', _('All protocols'));
		o.value('all', _('All protocols'));
		o.value('tcp', 'TCP');
		o.value('udp', 'UDP');
		o.value('tcp udp', 'TCP + UDP');
		o.value('icmp', 'ICMP');
		o.value('esp', 'ESP (IPsec)');
		o.value('gre', 'GRE');
		o.default = '';
		o.rmempty = true;

		o = s.taboption('general', form.Value, 'src_port', _('Source Port'),
			_('Match source port. Supports single port, range (e.g. 607-3000), or comma/space separated (e.g. 80,443,8080). Leave empty to match all ports.'));
		o.placeholder = '607-3000';
		o.rmempty = true;
		o.depends('proto', 'tcp');
		o.depends('proto', 'udp');
		o.depends('proto', 'tcp udp');
		o.validate = function(section_id, value) {
			if (!value || value === '') return true;
			var ports = value.replace(/,/g, ' ').trim().split(/\s+/);
			for (var i = 0; i < ports.length; i++) {
				var p = ports[i];
				if (/^\d+$/.test(p)) {
					var n = parseInt(p, 10);
					if (n < 1 || n > 65535) return _('Invalid port: %s').format(p);
				} else if (/^\d+-\d+$/.test(p)) {
					var parts = p.split('-');
					var a = parseInt(parts[0], 10), b = parseInt(parts[1], 10);
					if (a < 1 || a > 65535 || b < 1 || b > 65535 || a > b)
						return _('Invalid port range: %s').format(p);
				} else {
					return _('Invalid port format: %s').format(p);
				}
			}
			return true;
		};

		o = s.taboption('general', form.Value, 'dest_port', _('Destination Port'),
			_('Match destination port. Supports single port, range (e.g. 607-3000), or comma/space separated (e.g. 80,443,8080). Leave empty to match all ports.'));
		o.placeholder = '80,443,8080';
		o.rmempty = true;
		o.depends('proto', 'tcp');
		o.depends('proto', 'udp');
		o.depends('proto', 'tcp udp');
		o.validate = function(section_id, value) {
			if (!value || value === '') return true;
			var ports = value.replace(/,/g, ' ').trim().split(/\s+/);
			for (var i = 0; i < ports.length; i++) {
				var p = ports[i];
				if (/^\d+$/.test(p)) {
					var n = parseInt(p, 10);
					if (n < 1 || n > 65535) return _('Invalid port: %s').format(p);
				} else if (/^\d+-\d+$/.test(p)) {
					var parts = p.split('-');
					var a = parseInt(parts[0], 10), b = parseInt(parts[1], 10);
					if (a < 1 || a > 65535 || b < 1 || b > 65535 || a > b)
						return _('Invalid port range: %s').format(p);
				} else {
					return _('Invalid port format: %s').format(p);
				}
			}
			return true;
		};

		// Advanced tab
		o = s.taboption('advanced', form.Flag, 'sticky', _('Sticky'),
			_('Keep connections on the same interface using connection tracking.'));
		o.default = '0';

		o = s.taboption('advanced', form.Value, 'timeout', _('Sticky Timeout'),
			_('Timeout in seconds for sticky sessions.'));
		o.datatype = 'uinteger';
		o.default = '600';
		o.depends('sticky', '1');

		return m.render();
	}
});
