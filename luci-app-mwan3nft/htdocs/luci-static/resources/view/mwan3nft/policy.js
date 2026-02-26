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

		m = new form.Map('mwan3nft', _('MultiWAN NFT - Policies'),
			_('Policies define how traffic is distributed across members.'));

		s = m.section(form.TypedSection, 'policy', _('Policies'));
		s.addremove = true;
		s.anonymous = false;
		s.addbtntitle = _('Add Policy');

		o = s.option(form.DynamicList, 'use_member', _('Members'),
			_('Select members to use in this policy. Order matters for failover.'));
		o.rmempty = false;

		// Populate member list from config
		uci.sections('mwan3nft', 'member', function(section) {
			o.value(section['.name'], section['.name']);
		});

		o = s.option(form.ListValue, 'last_resort', _('Last Resort'),
			_('Action when all members are offline.'));
		o.value('default', _('Use default routing'));
		o.value('unreachable', _('Reject with ICMP unreachable'));
		o.value('blackhole', _('Drop silently'));
		o.default = 'default';

		return m.render();
	}
});
