classdef psaForage < handle
    % psaForage Pre Saccadic Attention Forage is a class for importing the
    % targetselection forage paradigm
   properties
       numTrials % number of trials run
       trial     % struct-array of trial values
       display   % display parameters from that session
   end
   
   methods
       
       function o = psaForage(PDS) % constructor
           
           if ~iscell(PDS)
               PDS = {PDS};
           end
           
           % --- find targetselection or dotselection trials
           stim = 'targetselection';
           
           hasStim = io.findPDScontainingStimModule(PDS, stim);
           
           stim = 'dotselection';
           
           hasStim = hasStim | io.findPDScontainingStimModule(PDS, stim);
           
           if ~any(hasStim)
               return
           end
           
           o.display = PDS{find(hasStim, 1, 'first')}.initialParametersMerged.display;
           
           
           for i = find(hasStim(:)')
               
               trial_ = o.importPDS(PDS{i});
               
               if isempty(trial_)
                   continue
               end
               
               o.trial = [o.trial; trial_(:)];
               
           end
           
           
           o.numTrials = numel(o.trial);
           
       end
       
   end
   
   methods (Static)
       function trial = importPDS(PDS)
           
           pdsDate = PDS.initialParametersMerged.session.initTime;
           
           if pdsDate > datenum(2018,05,14)
               trial = [];
           else
               trial = session.psaForage.importPDS_v1(PDS);
           end
           
       end
       
       function psaTrial = importPDS_v1(PDS)
           psaTrial = struct();
           
           % --- find CSD flash trials
           stim = 'dotselection';
           
           trialIx = cellfun(@(x) isfield(x, stim), PDS.data);
           
           stimTrials = find(trialIx);
           
           dot1RewardRate = PDS.initialParametersMerged.(stim).rewardDot1Rate;
           dot2RewardRate = PDS.initialParametersMerged.(stim).rewardDot2Rate;
           stimVisible    = PDS.initialParametersMerged.(stim).stimVisible;
           
           for j = 1:numel(stimTrials)
               thisTrial = stimTrials(j);
               
               kTrial = j;
               
               psaTrial(kTrial).frameTimes = PDS.PTB2OE(PDS.data{thisTrial}.timing.flipTimes(1,1:end-1));
               psaTrial(kTrial).start      = psaTrial(kTrial).frameTimes(1);
               psaTrial(kTrial).duration   = PDS.PTB2OE(PDS.data{thisTrial}.timing.flipTimes(1,end-1)) - psaTrial(kTrial).start;
               
               fixBehavior = PDS.initialParametersMerged.(stim).fixationBehavior;
               
               % fixation point onset
               onsetIndex = PDS.data{thisTrial}.(fixBehavior).hFix.log(1,:)==1;
               psaTrial(kTrial).fixOn      = PDS.PTB2OE(PDS.data{thisTrial}.(fixBehavior).hFix.log(2,onsetIndex));
               
               % fixation point offset
               offsetIndex = PDS.data{thisTrial}.(fixBehavior).hFix.log(1,:)==0;
               psaTrial(kTrial).fixOff     = PDS.PTB2OE(PDS.data{thisTrial}.(fixBehavior).hFix.log(2,offsetIndex));
               
               % fixation entered
               ix = PDS.data{thisTrial}.(fixBehavior).hFix.fixlog(1,:)==1;
               psaTrial(kTrial).fixEntered = PDS.PTB2OE(PDS.data{thisTrial}.(fixBehavior).hFix.fixlog(2,ix));
               
               % final fixation point offset (transition to state 2)
               psaTrial(kTrial).goSignal   = PDS.PTB2OE(PDS.data{thisTrial}.(stim).states.getTxTime(2));
               psaTrial(kTrial).targets    = PDS.data{thisTrial}.(stim).hTargs;
               psaTrial(kTrial).numTargs   = numel(psaTrial(kTrial).targets);
               
               nt = max(arrayfun(@(x) size(x.log,2), psaTrial(kTrial).targets));
               psaTrial(kTrial).targsOn = nan(psaTrial(kTrial).numTargs, nt);
               psaTrial(kTrial).targsOff = nan(psaTrial(kTrial).numTargs, nt);
               
               for iTarg = 1:psaTrial(kTrial).numTargs
                   nt = size(psaTrial(kTrial).targets(iTarg).log,2);
                   ix = psaTrial(kTrial).targets(1).log(1,:) == 1; 
                   if ~any(ix) % target never turned on
                       continue
                   end
                   psaTrial(kTrial).targsOn(iTarg, 1:nt) = PDS.PTB2OE(psaTrial(kTrial).targets(1).log(2,ix));
                   ix = psaTrial(kTrial).targets(1).log(1,:) == 0;
                   if ~any(ix)
                       % target turned off at last frame
                        psaTrial(kTrial).targsOff(iTarg, 1) = PDS.PTB2OE(PDS.data{thisTrial}.(stim).states.getTxTime(PDS.data{thisTrial}.(stim).states.stateId));
                   else
                        psaTrial(kTrial).targsOff(iTarg, 1:nt)= PDS.PTB2OE(psaTrial(kTrial).targets(1).log(2,ix));
                   end
               end
               
               psaTrial(kTrial).targChosen = PDS.data{thisTrial}.(stim).dotsChosen;
               if isnan(psaTrial(kTrial).targChosen)
                   psaTrial(kTrial).choiceTime = nan;
               else
                   ix = psaTrial(kTrial).targets(psaTrial(kTrial).targChosen).fixlog(1,:)==1;
                   psaTrial(kTrial).choiceTime = PDS.PTB2OE(psaTrial(kTrial).targets(psaTrial(kTrial).targChosen).fixlog(2,ix));
               end
               
               psaTrial(kTrial).targPosX    = arrayfun(@(x) x.position(1) - PDS.initialParametersMerged.display.ctr(1), psaTrial(kTrial).targets)/PDS.initialParametersMerged.display.ppd;
               psaTrial(kTrial).targPosY    = arrayfun(@(x) x.position(2) - PDS.initialParametersMerged.display.ctr(2), psaTrial(kTrial).targets)/PDS.initialParametersMerged.display.ppd;
               psaTrial(kTrial).targDirecion = [psaTrial(kTrial).targets.theta];
               if isa(psaTrial(kTrial).targets(1), 'stimuli.objects.gaborTarget')
                   psaTrial(kTrial).targSpeed = arrayfun(@(x) x.tf/x.sf, psaTrial(kTrial).targets);
               else
                   error('Need to implement this for dots')
               end
               
               % check if reward conditions changed
               fnames = fieldnames(PDS.conditions{thisTrial}.(stim));
               if any(strcmp(fnames, 'rewardDot1Rate'))
                    dot1RewardRate = PDS.conditions{thisTrial}.(stim).rewardDot1Rate;
               end
               
               if any(strcmp(fnames, 'rewardDot2Rate'))
                   dot2RewardRate = PDS.conditions{thisTrial}.(stim).rewardDot2Rate;
               end
               
               if any(strcmp(fnames, 'stimVisible'))
                   stimVisible = PDS.conditions{thisTrial}.(stim).stimVisible;
               end
               
               psaTrial(kTrial).rewardRate = [dot1RewardRate dot2RewardRate];
               psaTrial(kTrial).stimVisible = stimVisible;
                
               % check for change in reward rate
               if kTrial > 1
                   if ~all((psaTrial(kTrial).rewardRate - psaTrial(kTrial-1).rewardRate) == 0)
                       psaTrial(kTrial).switchReward = 1;
                   else
                       psaTrial(kTrial).switchReward = 0;
                   end
               else
                   psaTrial(kTrial).switchReward = 1;
               end
               
               psaTrial(kTrial).isRewarded = PDS.data{thisTrial}.(stim).isRewarded;
                   
                
               % align stimuli that are yoked to the frame to the frame
               % rate
%                psaTrial(kTrial).fixOn = session.psaForage.alignToNextFrame(psaTrial(kTrial).fixOn, psaTrial(kTrial).frameTimes);
%                psaTrial(kTrial).fixOff = session.psaForage.alignToNextFrame(psaTrial(kTrial).fixOff, psaTrial(kTrial).frameTimes);
               
               
           end
           
           
       end
       
       function alignedTimes = alignToNextFrame(cpuTime, frameTimes)
            diffs = bsxfun(@minus, cpuTime(:)', frameTimes(:))<0;
            n = numel(cpuTime);
            alignedTimes = nan(size(cpuTime));
            for i = 1:n
                alignedTimes(i) = frameTimes(find(diffs(:,i), 1, 'first'));
            end
           
       end
   end
end