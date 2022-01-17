clc;
disp('========= ZED SDK PLUGIN =========');
disp('-- Retrieve Images and Depth --');
close all;
clear mex; clear functions; clear all;

% initial parameter structure, the same as sl::InitParameters
% values as enum number, defines in : sl/defines.hpp
% or from https://www.stereolabs.com/docs/api/structsl_1_1InitParameters.html

InitParameters.camera_resolution = 2; %HD720
InitParameters.camera_fps = 60;
InitParameters.coordinate_units = 2; %METER
InitParameters.depth_mode = 1; %PERFORMANCE
%InitParameters.svo_input_filename = '../mySVOfile.svo'; % Enable SVO playback
InitParameters.depth_maximum_distance = 7;% Define maximum depth (in METER)
result = mexZED('open', InitParameters);

if(strcmp(result,'SUCCESS')) % the Camera is open
    
    % basic informations
    camInfo = mexZED('getCameraInformation');
    image_size = [camInfo.left_cam.width camInfo.left_cam.height] 
    
    requested_depth_size = [720 404];
    
    % init depth histogram
    binranges = 0.5:0.25:InitParameters.depth_maximum_distance;
    
    % (optional) Get number of frames (if SVO)
    nbFrame = mexZED('getSVONumberOfFrames');    
    
    % Create Figure and wait for keyboard interruption to quit
    f = figure('name','ZED SDK : Images and Depth','NumberTitle','off','keypressfcn',@(obj,evt) 0);
        
    % Setup runtime parameters
    RuntimeParameters.sensing_mode = 0; % STANDARD sensing mode
    
    key = 1;
    img_num = 0;
    % loop over frames, till Esc is pressed
    while (key ~= 27)
        % grab the current image and compute the depth
        result = mexZED('grab', RuntimeParameters);        
        if(strcmp(result,'SUCCESS'))
            % retrieve letf image
            image_left = mexZED('retrieveImage', 2); %left
            % retrieve right image
            image_right = mexZED('retrieveImage', 1); %right
            
            % image timestamp
            im_ts = mexZED('getTimestamp', 0) 
                        
            % retrieve depth as a normalized image
            image_depth = mexZED('retrieveImage', 9); %depth
            % retrieve the real depth, resized
            depth = mexZED('retrieveMeasure', 1, requested_depth_size(1), requested_depth_size(2)); %depth
            disparity = mexZED('retrieveMeasure', 0, requested_depth_size(1), requested_depth_size(2)); %disparity
            disparity = double(disparity * -1.0);

            % Convert nan/inf to 0
            disparity(~(isfinite(disparity))) = 0;
            %disparity(isnan(disparity)) = 0;
            %disparity(isinf(disparity)) = 0;

            t_disparity = t_disp(disparity);

            subplot(4,2,1)
            imshow(image_left);
            title('Image Left')
            subplot(4,2,2)
            imshow(image_right);
            title('Image Right')
            subplot(4,2,3)
            imshow(image_depth);
            title('Depth')
            subplot(4,2,4)
            % Compute the depth histogram
            val_ = find(isfinite(depth(:))); % handle wrong depth values
            depth_v = depth(val_);
            [bincounts] = histc(depth_v(:),binranges);
            bar(binranges,bincounts,'histc')
            title('Depth histogram')
            xlabel('meters')
            subplot(4,2,5)
            imshow(depth);
            title('Depth Raw')
            subplot(4,2,6)
            imshow(disparity);
            title('Disparity Raw')

            subplot(4,2,7);
            imshow(disparity, [],'Colormap',jet(4096));
            title('Disparity Map');
            subplot(4,2,8);
            imshow(t_disparity,[],'Colormap',jet(4096));
            title('T Disparity Map');

            % Write rgb and t_disp to png
            img_name = [num2str(img_num) '.png'];
            imwrite(t_disparity, img_name);

            img_num = img_num + 1;       

            drawnow; %this checks for interrupts
            key = uint8(get(f,'CurrentCharacter'));
            if(~length(key))
                key=0;
            end
        end
    end
    close(f)
end

% Make sure to call this function to free the memory before use this again
mexZED('close')
disp('========= END =========');
clear mex;