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

		m = new form.Map('mwan3nft', _('MultiWAN NFT - Members'),
			_('Members link interfaces with metrics and weights for use in policies.'));

		s = m.section(form.TypedSection, 'member', _('Members'));
		s.addremove = true;
		s.anonymous = false;
		s.addbtntitle = _('Add Member');

		s.tab('general', _('General'));

		o = s.taboption('general', form.ListValue, 'interface', _('Interface'),
			_('Select the WAN interface for this member.'));
		o.rmempty = false;

		// Populate interface list from config
		uci.sections('mwan3nft', 'interface', function(section) {
			o.value(section['.name'], section['.name']);
		});

		o = s.taboption('general', form.Value, 'metric', _('Metric'),
			_('Lower metric means higher priority. Members with the same metric will load balance.'));
		o.datatype = 'uinteger';
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('general', form.Value, 'weight', _('Weight'),
			_('Weight for load balancing. Higher weight means more traffic.'));
		o.datatype = 'uinteger';
		o.default = '1';
		o.rmempty = false;

		return m.render();
	}
});
