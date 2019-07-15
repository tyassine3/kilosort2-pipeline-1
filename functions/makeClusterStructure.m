function makeClusterStructure(rawdatadir, clusterdir, files,...
    probeChannels, brainReg)
% makeClusterStructure Make post curation data structure for Kilosort2.
%   ALP 7/14/19

for br = 1:length(brainReg)
    anclusterdir = [clusterdir, brainReg{br}];
    
    %read clustered information
    spikeInds = readNPY([anclusterdir, 'spike_times.npy']); %in indices
    spikeID = readNPY([anclusterdir, 'spike_clusters.npy']);
    [clusterID, clusterGroup] = readClusterGroupsCSV([anclusterdir, 'cluster_groups.csv']);
    templates = readNPY([anclusterdir, 'templates.npy']);
    spikeTemplates = readNPY([anclusterdir, 'spike_templates.npy']);
    channelMap = readNPY([anclusterdir, 'channel_map.npy']);
    params = loadParamsPy([anclusterdir, 'params.py']);
%     load([anclusterdir, 'sortingprops.mat'], props)
    props.recLength = [60*20000 60*20000 60*20000];

    %only units classified as "good"
    goodUnits = clusterID(clusterGroup == 2);
    
    %get templates for each cluster
    tempPerUnit = findTempForEachClu(spikeID, spikeTemplates);
    
    %get max channel per cluster based on max template amplitude
    [~,max_site] = max(max(abs(templates),[],2),[],3);
    templateMaxChan = channelMap(max_site); %0 based, template 0 is at ind 1
    unitMaxChan = templateMaxChan(tempPerUnit(~isnan(tempPerUnit))+1);
    unitMaxChan = double(unitMaxChan(clusterGroup == 2)); %only good units
    
    %create structure
    clusters = struct('ID', num2cell(goodUnits), ...
        'spikeInds', repmat({[]}, 1, length(goodUnits)),...
        'sampRate', num2cell(params.sample_rate*ones(1, length(goodUnits))), ...
        'maxChan', num2cell(unitMaxChan'));
    
    %loop over recordings - this could be improved - how does Lu do it?
    elapsedLength = 0;
    for f = 1:length(files)
        for clu = 1:length(goodUnits)
            if f == 1
                tempSpikeInds{clu} = spikeInds(spikeID == goodUnits(clu));
                tempSpikeInds{clu} = double(tempSpikeInds{clu});
            else
                clusters(clu).spikeInds = [];
            end
            
            clusters(clu).spikeInds = tempSpikeInds{clu}(tempSpikeInds{clu} <= f*props.recLength(f))-elapsedLength;
            
            if f < length(files)
                tempSpikeInds{clu} = tempSpikeInds{clu}(tempSpikeInds{clu} > f*props.recLength(f));
            end
            clusters(clu).file = files(f);
        end
        elapsedLength = elapsedLength+props.recLength(f);
        
        save([anclusterdir, 'clusters', num2str(files(f)), '.mat'], 'clusters')
    end
end
end
