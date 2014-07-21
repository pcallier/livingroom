% Makes a textgrid (at tg_filename) that shows where the creaky bits in the wav file
% at snd_filename are. uses the cutoffs from covarep; can possibly	 be modified to use different
% threshold.
% This only works if you've loaded John Kane et al.'s covarep
% libraries, e.g. by running the startup script in the covarep base directory

% This interprets the detector's chunks as ending at the time given in 2nd column of results. Haven't
% actually confirmed this with how the detector works, but it seems to fit.

function creak_tg(snd_filename, tg_filename)

[x, fs] = wavread(snd_filename);

if size(x,1)/fs < 0.100
	warning(strcat(snd_filename, ' less than 100 ms long'));
	return
else
	disp(snd_filename)
end

if fs ~= 16000
	warning('Sampling frequencies other than 16000 Hz are not known to work.')
end

[creak_pp,creak_bin] = detect_creaky_voice(x,fs);
diff_bin = diff([1 creak_bin(:, 1).' 1]);
start_index = find(diff_bin < 0)
end_index = find(diff_bin > 0)-1

stepsize_frames = creak_bin(1,2);
stepsize_secs = stepsize_frames / fs;

tg_file = fopen(tg_filename, 'w');
min_time = 0;
max_time = size(x,1) / fs;

fprintf(tg_file, '"Praat chronological TextGrid text file"\n');
fprintf(tg_file, '%f %f   ! Time domain.\n', min_time, max_time);
fprintf(tg_file, '1   ! Number of tiers.\n');
fprintf(tg_file, '"IntervalTier" "creak" %f %f\n\n', min_time, max_time);

if size(start_index, 2) > 1
	% get the start of the grid right
	endoflast = min_time;
	if creak_bin(1,1) == 1
		fprintf(tg_file, '1 %f %f\n"creak"\n\n',  min(min_time,creak_bin(1,2)/fs - stepsize_secs),  creak_bin(start_index(1),2)/fs - stepsize_secs)
		endoflast = creak_bin(start_index(1),2)/fs - stepsize_secs;
	end
	fprintf(tg_file, '1 %f %f\n""\n\n',  endoflast,  creak_bin(end_index(1),2)/fs);
	fprintf(tg_file, '1 %f %f\n"creak"\n\n',  creak_bin(end_index(1),2)/fs,  creak_bin(start_index(2),2)/fs - stepsize_secs);


	for i = 2:size(start_index,2)
		% first put down the blank specified in start_index, then the corresponding creaky bit
		if i ~= size(start_index,2)
			fprintf(tg_file, '1 %f %f\n""\n\n', creak_bin(start_index(i),2)/fs - stepsize_secs,  creak_bin(end_index(i),2)/fs);
			fprintf(tg_file, '1 %f %f\n"creak"\n\n', creak_bin(end_index(i),2)/fs,  creak_bin(start_index(i+1),2)/fs - stepsize_secs);
		else
			% last row: end with creak or blank?
			if end_index(i) == size(creak_bin,1)
				fprintf(tg_file, '1 %f %f\n""\n\n', creak_bin(start_index(i),2)/fs  - stepsize_secs,  max_time);
			else
				fprintf(tg_file, '1 %f %f\n""\n\n', creak_bin(start_index(i),2)/fs - stepsize_secs,  creak_bin(end_index(i),2)/fs);
				fprintf(tg_file, '1 %f %f\n"creak"\n\n', creak_bin(end_index(i),2)/fs,  max_time);	
			end
		end
	end
elseif size(start_index, 2) == 1
	fprintf(tg_file, '1 %f %f\n""\n\n',  min_time,  max_time);
else
	fprintf(tg_file, '1 %f %f\n"creak"\n\n',  min_time,  max_time);	
end

fclose(tg_file);
