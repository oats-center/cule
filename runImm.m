function [gd_imm] = runImm(gd)
%RUNIMM perform IMM algorithm on the specified GPS data mat file
%
%   IMM algorithm does not handle GPS points that are too far apart.
%   In this script, we check when the timestamps of the GPS data are too far
%   apart and break the GPS data into segments and then call runImmSingle on
%   these segments.
%
%   Parameters:
%     gd - gps data
%
%   Parameters:
%     gd_imm - gps data with IMM outputs
%
%  Yang Wang 06/04/2019

  addpath('./algorithms/imm-wang/');

  if length(gd) == 0
    gd_imm = {};
    fprintf('\tNo GPS data in this field, skip to the next one!\n\n');
    return
  end

  % copy the original struct contents
  for m = 1:length(gd)
    for fn = fieldnames(gd{m})'
      gd_imm{m}.(fn{1}) = gd{m}.(fn{1});
    end
  end

  % before running imm, segment the data based on outage
  % find the total outage count and their indices
  for m = 1:length(gd_imm)
    outage_ind = [];
    outage_cnt = 0;
    fprintf('\tFinding outage in dataset %d out of %d total sets:\n', ...
      m, length(gd_imm));

    for l = 1:(length(gd_imm{m}.gpsTime)-1)
      % Get the dt from data
      dt = (gd_imm{m}.gpsTime(l+1) - gd_imm{m}.gpsTime(l)) / 1000;
      if dt > 10
        outage_cnt = outage_cnt + 1;
        outage_ind(outage_cnt) = l;
      end
    end

    % get the outage indices
    gd_imm{m}.outages = outage_ind;
    fprintf('\t\tIn %s, there are %d outages out of %d points.\n', ...
      gd_imm{m}.id, length(gd_imm{m}.outages), length(gd_imm{m}.time));

    if length(gd_imm{m}.outages) == 1
      gd_imm_seg = cell(1, 2);
    elseif length(gd_imm{m}.outages) == 0
      % nop
    else
      gd_imm_seg = cell(1, length(gd_imm{m}.outages));
    end
  end

  fprintf('\n');

  % allocate gps data segments
  for m = 1:length(gd_imm)
    if length(gd_imm{m}.outages) == 1
      fprintf('\tBreak %s data into 2 parts for IMM due to outages:\n', ...
        gd_imm{m}.id);
      cnt = 2;
    elseif length(gd_imm{m}.outages) == 0
      fprintf('\tNo outage for %s data, run normal IMM:\n', ...
       gd_imm{m}.id);
      gd_imm{m} = runImmSingle(gd_imm{m});
      cnt = 0;
    else
      fprintf('\tBreak %s data into %d parts for IMM due to outages:\n', ...
        gd_imm{m}.id, length(gd_imm{m}.outages)+1);
      cnt = length(gd_imm{m}.outages)+1;
    end

    % copy and remove some fields so that structfun can work
    m_type = gd_imm{m}.type;
    id = gd_imm{m}.id;
    outages = gd_imm{m}.outages;
    gd_imm_tmp = rmfield(gd_imm{m}, {'type', 'id', 'outages'});

    if cnt == 2 % when there is only one outage
      % copy everything else
      gd_imm_seg{1} = ...
        structfun(@(x) ...
          x(1:(outages(1))), ...
          gd_imm_tmp, 'uniformoutput', 0);
      gd_imm_seg{1}.id = id;
      gd_imm_seg{1}.type = m_type;

      % run IMM
      fprintf('\t\tRunning segments 1 to %d\n', outages(1));
      gd_imm_seg{1} = runImmSingle(gd_imm_seg{1});

      gd_imm_seg{2} = ...
        structfun(@(x) ...
          x((outages(1)+1):end), ...
          gd_imm_tmp, 'uniformoutput', 0);
      gd_imm_seg{2}.id = id;
      gd_imm_seg{2}.type = m_type;

      % run IMM
      fprintf('\t\tRunning segments %d to end\n', outages(1)+1);
      gd_imm_seg{2} = runImmSingle(gd_imm_seg{2});
    elseif cnt == 0 % when there is no outage
      % nop
    else
      % copy everything else
      gd_imm_seg{1} = ...
        structfun(@(x) ...
          x(1:(outages(1))), ...
          gd_imm_tmp, 'uniformoutput', 0);
      gd_imm_seg{1}.id = id;
      gd_imm_seg{1}.type = m_type;

      % run IMM
      fprintf('\t\tRunning segments 1 to %d\n', outages(1));
      gd_imm_seg{1} = runImmSingle(gd_imm_seg{1});

      for nn = 1:(cnt-2)
        % copy everything else
        gd_imm_seg{nn+1} = ...
          structfun(@(x) ...
            x((outages(nn)+1):(outages(nn+1))), ...
            gd_imm_tmp, 'uniformoutput', 0);
        gd_imm_seg{nn+1}.id = id;
        gd_imm_seg{nn+1}.type = m_type;

        % run IMM
        fprintf('\t\tRunning segments %d to %d\n', ...
          outages(nn)+1, outages(nn+1));
        gd_imm_seg{nn+1} = runImmSingle(gd_imm_seg{nn+1});
      end

      gd_imm_seg{cnt} = ...
        structfun(@(x) ...
          x((outages(cnt-1)+1):end), ...
          gd_imm_tmp, 'uniformoutput', 0);
      gd_imm_seg{cnt}.id = id;
      gd_imm_seg{cnt}.type = m_type;

      % run IMM
      fprintf('\t\tRunning segments %d to end\n', outages(cnt-1)+1);
      gd_imm_seg{cnt} = runImmSingle(gd_imm_seg{cnt});
    end

    if cnt ~= 0
      gd_imm{m}.time = {};
      gd_imm{m}.gpsTime = [];
      gd_imm{m}.lat = [];
      gd_imm{m}.lon = [];
      gd_imm{m}.altitude = [];
      gd_imm{m}.speed = [];
      gd_imm{m}.bearing = [];
      gd_imm{m}.accuracy = [];
      gd_imm{m}.mu = []; % IMM estimated model probabilities, c1: NCV, c2: NCT
      gd_imm{m}.v = []; % IMM estimated speed
      gd_imm{m}.tr = []; % IMM estimated turn rate
      gd_imm{m}.x = []; % IMM estimated x
      gd_imm{m}.y = []; % IMM estimated y

      % and then we need to put everything back together
      for oo = 1:cnt
        gd_imm{m}.time = [gd_imm{m}.time; gd_imm_seg{oo}.time];
        gd_imm{m}.gpsTime = [gd_imm{m}.gpsTime; gd_imm_seg{oo}.gpsTime];
        gd_imm{m}.lat = [gd_imm{m}.lat; gd_imm_seg{oo}.lat];
        gd_imm{m}.lon = [gd_imm{m}.lon; gd_imm_seg{oo}.lon];
        gd_imm{m}.altitude = [gd_imm{m}.altitude; gd_imm_seg{oo}.altitude];
        gd_imm{m}.speed = [gd_imm{m}.speed; gd_imm_seg{oo}.speed];
        gd_imm{m}.bearing = [gd_imm{m}.bearing; gd_imm_seg{oo}.bearing];
        gd_imm{m}.accuracy = [gd_imm{m}.accuracy; gd_imm_seg{oo}.accuracy];
        gd_imm{m}.mu = [gd_imm{m}.mu; gd_imm_seg{oo}.mu];
        gd_imm{m}.v = [gd_imm{m}.v; gd_imm_seg{oo}.v];
        gd_imm{m}.tr = [gd_imm{m}.tr; gd_imm_seg{oo}.tr];
        gd_imm{m}.x = [gd_imm{m}.x; gd_imm_seg{oo}.x];
        gd_imm{m}.y = [gd_imm{m}.y; gd_imm_seg{oo}.y];
      end
    end
  end

  fprintf('\n');

end %EOF
