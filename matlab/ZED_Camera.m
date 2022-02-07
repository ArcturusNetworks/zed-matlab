clc;
disp('========= ZED SDK PLUGIN =========');
disp('-- Retrieve Images and Depth --');
close all; clear mex; clear functions; clear all;

try
    mexZED('close')
catch ML
    % fprintf('%s: %s', ML.identifier,ML.message)
end

% initial parameter structure, the same as sl::InitParameters
% values as enum number, defines in : sl/defines.hpp
% or from https://www.stereolabs.com/docs/api/structsl_1_1InitParameters.html

InitParameters.camera_resolution = 0; %0=2k 1=1080P 2=HD720P
InitParameters.camera_fps = 60;
InitParameters.coordinate_units = 2; %0=MM 1=CM 2=M 3=IN 4=FT
InitParameters.depth_mode = 1; %0=NONE 1=PERFORMANCE 2=QUALITY 3=ULTRA
windowName = 'ZED Camera';
if (~mexZED('isZEDconnected'))
    svofiles = dir("*.svo");
    if (~length(svofiles)>0)
        fprintf('Unable to find any .svo files. Exiting.');
    else
        % InitParameters.svo_input_filename = [svofiles(1).name];
        %InitParameters.svo_input_filename = ['HD2K_SN39380257_17-13-22.svo'];
        InitParameters.svo_input_filename = ['HD720_SN39380257_17-12-27.svo'];
        windowName = svofiles(1).name;
    end
end
%InitParameters.depth_minimum_distance = 0;% Define maximum dept
%InitParameters.depth_maximum_distance = 7;% Define maximum dept
result = mexZED('open', InitParameters);

try
    if(strcmp(result,'SUCCESS')) % the Camera is open
        
        % basic informations
        camInfo = mexZED('getCameraInformation');
        image_size = [camInfo.left_cam.width camInfo.left_cam.height];
        
        requested_depth_size = image_size;
    %     %requested_depth_size = [1280 720];
        
        % (optional) Get number of frames (if SVO)
        nbFrame = mexZED('getSVONumberOfFrames');    
        
        % set colormap for saving transformed disparity maps
        load("CustomColorMap.mat");
        cmap = CustomColorMap;
    
        % Create Figure and wait for keyboard interruption to quit
        x0=0;
        y0=0;
        width=500;
        height=800;
        f = figure('name',windowName,'NumberTitle','off','keypressfcn',@(obj,evt) 0);
        set(gcf,'WindowState', 'Maximized')
        % Setup runtime parameters
        RuntimeParameters.sensing_mode = 0; % STANDARD sensing mode
    
        enable_crop = true;
        key = 1;
        img_num = 0;
        % loop over frames, till Esc is pressed
        while (1)
            % grab the current image and compute the depth
            result = mexZED('grab', RuntimeParameters);
            if(strcmp(result,'SUCCESS'))
    
                image_left = mexZED('retrieveImage', 0,requested_depth_size(1), requested_depth_size(2));
                %left_gray = mexZED('retrieveImage', 2,requested_depth_size(1), requested_depth_size(2));
                %image_right = mexZED('retrieveImage', 1,requested_depth_size(1), requested_depth_size(2));
                %right_gray = mexZED('retrieveImage', 3,requested_depth_size(1), requested_depth_size(2));
                im_ts = mexZED('getTimestamp', 0);
                
                depth = mexZED('retrieveMeasure', 1, requested_depth_size(1), requested_depth_size(2));
                disparity = mexZED('retrieveMeasure', 0, requested_depth_size(1), requested_depth_size(2));
                
                if (enable_crop)
                    crop_rect = centerCropWindow2d(size(image_left), ...
                        [requested_depth_size(2) requested_depth_size(1)-round(0.25*requested_depth_size(1))]);
                    [image_left, rect] = imcrop(image_left, crop_rect);
                    [depth, rect] = imcrop(depth, crop_rect);
                    [disparity, rect] = imcrop(disparity, crop_rect);
                end
                % Convert nan/inf to 0
                disparity = double(disparity * -1.0);
                disparity(~(isfinite(disparity))) = 0;
    
                tic;
                t_disparity = t_disp(disparity);
                toc;
    
                % save rgb and t_disp (with colormap) as png
                t_disp_path = ['./output/t_disp/' num2str(img_num) '.png'];
                rgb_path = ['./output/rgb/' num2str(img_num) '.png'];
    
                subplot(2,2,1)
                %labeloverlay(image_left, sprintf('%d/%d', img_num, nbFrame));
                imshow(image_left);
                title('Image Left')
    
                subplot(2,2,2);
                imshow(depth,[],'Colormap',jet(4096));
                colorbar;
                title('Depth');
    
                subplot(2,2,3);
                imshow(disparity,[],'Colormap',jet(4096));
                colorbar;
                title('Disparity');
    
                subplot(2,2,4);
                imshow(rescale(t_disparity).*255, [], 'Colormap',cmap);
                colorbar;
                title('T Disparity Map');
                
                img_num = img_num + 1;   
    
                %clear disparity t_disparity;
    
                drawnow;
    
                % check for interrupts
                key = uint8(get(f,'CurrentCharacter'));
                if (isempty(key))
                    key=0;
                else
                    ask_plus = key == 45; % press '+'
                    ask_minus = key == 43; % press '-'
                    if(ask_plus || ask_minus)
                        % get current Camera brightness value
                        brightness = mexZED('getCameraSettings','brightness');
                        if(ask_plus && (brightness>0)) % decrease value
                            brightness = brightness - 1;
                        end
                        if(ask_minus && (brightness<8)) % increase value
                            brightness = brightness + 1;
                        end
                        brightness;
                        % set the new value
                        mexZED('setCameraSettings', 'brightness', brightness);
                    
                    elseif (key == 28) % left arrow key
                        position = mexZED('getSVOPosition') - 50;
                        position = max(0, position);
                        mexZED('setSVOPosition', position)
                    
                    elseif (key == 29) % right arrow key
                        position = mexZED('getSVOPosition') + 50;
                        position = min(nbFrame, position);
                        mexZED('setSVOPosition', position)
                    
                    elseif (key == 'c')
                        enable_crop = ~enable_crop;

                    elseif(key == 'd') % press 'd' to reset to the default value
                        disp('reset to default');
                        mexZED('setCameraSettings', 'brightness', -1); % set auto value
                        roi = [0,0,image_size(1), image_size(2)];
                        mexZED('setCameraSettings', 'aec_agc_roi', roi, 2, 1); % set auto Gain/Exposure on full image
                    
                    elseif(key == 'r') % press 'r'  to use the auto Gain/Exposure on a defineded ROI
                        roi = [image_size(1)/4, image_size(2)/4, image_size(1)/2, image_size(2)/2];
                        mexZED('setCameraSettings', 'aec_agc_roi', roi);
                    
                    elseif (key == 's')
                        imwrite(rescale(t_disparity).*255, cmap, t_disp_path);
                        imwrite(image_left, rgb_path);
                        fprintf("images saved\n");
                    
                    elseif (key == 32) % space bar
                        waitforbuttonpress;

                    elseif (key == 27 || key == 'q')
                        break;
                    
                    else
                        disp('q/Esc - exit');
                        disp('space - play/pause');
                        disp('left arrow - rewind');
                        disp('right arrow - fast-forward');
                        disp('s - save as PNGs');
                        disp('+/- - increase/decrease brightness');
                        disp('r - enable/disable aec_agc');
                        disp('c - enable/disable crop');
                        disp('d - reset default values for brightness and aec_agc');
                    end

                end
                set(f,'CurrentCharacter','0'); % reset pressed key
            else
                break;
            end
        end
        close(f)
    end
catch ML
    fprintf('%s: %s', ML.identifier,ML.message)
end

try
    % Make sure to call this function to free the memory before use this again
    mexZED('close');
catch ML
    fprintf('%s: %s', ML.identifier,ML.message)
end
disp('========= END =========');