function eegplugin_ddtobox(fig, try_strings, catch_strings)



% create menu
eeglabmenu = findobj(fig,'tag','EEGLAB');
% get(fig,'Children')
helpmenu =  findobj(fig, 'label', 'Help');
pos = get(helpmenu,'position') - 1;
ddmenu = uimenu(eeglabmenu, 'label', 'DDTBOX',...
   'separator','on',...
   'tag','DDTBOX', ...
   'userdata', 'startup:on;epoch:on;continuous:off;chanloc:on;');
set(ddmenu,'position',pos);

uimenu(ddmenu, 'label', 'Decode',...
   'separator','off',...,
   'tag','decode', ... 
   'callback', 'fprintf(''decode!\n'')',...
   'userdata', 'epoch:on;continuous:off;chanloc:on;');

uimenu(ddmenu, 'label', 'Plot single subject results',...
   'separator','off',...,
   'tag','plotss', ... 
   'callback', 'fprintf(''plot single subject results!\n'')',...
   'userdata', 'epoch:on;continuous:off;chanloc:on;');

uimenu(ddmenu, 'label', 'Analyse',...
   'separator','on',...,
   'tag','analyse', ... 
   'callback', 'fprintf(''analyse!\n'')',...
   'userdata', 'epoch:on;continuous:off;chanloc:on;');


