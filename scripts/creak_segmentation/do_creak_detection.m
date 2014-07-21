function do_creak_detection(folder_name)

getname = @(x) getfield(x, 'name');
file_list = dir(fullfile(folder_name, '*.wav'));
file_names = arrayfun(getname, file_list, 'UniformOutput', false);
tg_names = strrep(file_names, '.wav', '.TextGrid');

for i = 1:size(file_names,1)
	creak_tg(fullfile(folder_name, file_names{i}), fullfile(folder_name,tg_names{i}))
end