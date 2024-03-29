function [totalDuration, uleIdx] = uleIdentify(year, dEps, muEps, vEps)

  % Load different data files from the same year
  cbPath = '~/research/cule/data/tablet/combine';
  gkPath = '~/research/cule/data/tablet/kart';

  cbAugerLocsFn = strcat(cbPath, '_immas_', num2str(year));
  gkCenterLocsFn = strcat(gkPath, '_immcc_', num2str(year));

  fprintf('Loading data `%s`\n', cbAugerLocsFn);

  load(cbAugerLocsFn);

  fprintf('Data was successfully loaded!\n');

  fprintf('Loading data `%s`\n', gkCenterLocsFn);

  load(gkCenterLocsFn);

  fprintf('Data was successfully loaded!\n');

  % Allocate the indices
  uleIdx = cell(length(gdImmAS), 1);
  totalDuration = cell(length(gdImmAS), 1);

  fprintf('uleIdentify started ...\n\n');
  tic;

  % Finding preliminary cules
  % 1. Use `computeUleParameters` to compute unloading event related parameters
  %    - They are the differences in:
  %      - speed
  %      - NCV model probabilities
  %      - distance
  fprintf('\tIdentifying ULEs ...\n')
  for m = 1:length(gdImmAS)
    fprintf('\tON FIELD %d\n', m);
    % We don't want to process the empty cells
    if isempty(gdImmAS{m})
      fprintf('\t\tNo GPS data in this field, skip to the next one!\n\n');
      continue
    end
    k = gdImmCC{m}{1};
    for n = 1:length(gdImmAS{m})
      fprintf('\t\tDATA SET %d\n', n);
      uleParameters = computeUleParameters(gdImmAS{m}{n}, k);
      boolUle = (uleParameters(:,1) <= dEps) ...
        & (uleParameters(:,2) >= -muEps & uleParameters(:,2) <= muEps) ...
        & (uleParameters(:,3) >= -vEps & uleParameters(:,3) <= vEps);

      [indicesStarts, indicesEnds] = findConsecutiveSubSeq(boolUle, 1);

      firstUlFlag = false;

      for nn = 1:length(indicesStarts)
        if (median(uleParameters(indicesStarts(nn):indicesEnds(nn),4)) >= 0.25)
          firstUlFlag = true;
        end

        numOfSamples = indicesEnds(nn) - indicesStarts(nn) + 1;
        if (firstUlFlag) & (numOfSamples < 15 || numOfSamples > 200)
          boolUle(indicesStarts(nn):indicesEnds(nn)) = zeros(numOfSamples, 1);
        end
      end
      uleIdx{m}{n} = find(boolUle);
      totalDuration{m}{n} = sum(boolUle);
    end
    fprintf('\n');
  end
  fprintf('\tDone!\n\n');

%  cleanUleIdx = cell(length(gdImmAS), 1);
%  uleSegs = cell(length(gdImmAS), 1);
%
%  % Cleaning cules
%  % 2. Use `cleanUles` to clean the unloading events
%  fprintf('\tCleaning raw ULEs ...\n')
%  for m = 1:length(gdImmAS)
%    for n = 1:length(gdImmAS{m})
%      [uleSegs{m}{n}.ts, uleSegs{m}{n}.totDur, uleSegs{m}{n}.id, ...
%        cleanUleIdx{m}{n}] = cleanUles(gdImmAS{m}{n}, uleIdx{m}{n});
%    end
%  end
%  fprintf('\tDone!\n\n');

  fprintf('uleIdentify finished!\n\n');
  toc;

end%EOF
