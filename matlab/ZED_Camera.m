clc;
disp('========= ZED SDK PLUGIN =========');
disp('-- Retrieve Images and Depth --');
close all; clear mex; clear functions; clear all;

% initial parameter structure, the same as sl::InitParameters
% values as enum number, defines in : sl/defines.hpp
% or from https://www.stereolabs.com/docs/api/structsl_1_1InitParameters.html

InitParameters.camera_resolution = 0; %0=2k 1=1080P 2=HD720P
InitParameters.camera_fps = 15;
InitParameters.coordinate_units = 2; %0=MM 1=CM 2=M 3=IN 4=FT
InitParameters.depth_mode = 3; %0=NONE 1=PERFORMANCE 2=QUALITY 3=ULTRA
%InitParameters.svo_input_filename = '/home/harshad/Downloads/2022_Jan_19_Wed_21_52_repaired.svo'; % Enable SVO playback
InitParameters.depth_minimum_distance = 0;% Define maximum depth
InitParameters.depth_maximum_distance = 2;% Define maximum depth
result = mexZED('open', InitParameters);

if(strcmp(result,'SUCCESS')) % the Camera is open
    
    % basic informations
    camInfo = mexZED('getCameraInformation');
    image_size = [camInfo.left_cam.width camInfo.left_cam.height];
    
    %requested_depth_size = [720 404];
    requested_depth_size = [1280 720];
    
    % init depth histogram
    binranges = 0.5:0.25:InitParameters.depth_maximum_distance;
    
    % (optional) Get number of frames (if SVO)
    nbFrame = mexZED('getSVONumberOfFrames');    
    
    % set colormap for saving transformed disparity maps
    cmap = jet(256);

    % Create Figure and wait for keyboard interruption to quit
    x0=0;
    y0=0;
    width=1000;
    height=2000;
    f = figure('name','ZED SDK : Images and Depth','NumberTitle','off','keypressfcn',@(obj,evt) 0);
    set(gcf,'position',[x0,y0,width,height])   
    % Setup runtime parameters
    RuntimeParameters.sensing_mode = 1; % STANDARD sensing mode

    crop_rect=[280,70,920,620];

    enable_crop = true;
    
    key = 1;
    img_num = 0;
    % loop over frames, till Esc is pressed
    while (key ~= 27)
        % grab the current image and compute the depth
        result = mexZED('grab', RuntimeParameters);
        if(strcmp(result,'SUCCESS'))
            image_left = mexZED('retrieveImage', 0, requested_depth_size(1), requested_depth_size(2));
            image_left_cropped = image_left;
            % [image_left_cropped,rect] = imcrop(image_left);
            [image_left_cropped, rect] = imcrop(image_left, crop_rect);
            im_ts = mexZED('getTimestamp', 0);
            
            depth = mexZED('retrieveImage', 9, requested_depth_size(1), requested_depth_size(2));
            disparity = mexZED('retrieveMeasure', 0, requested_depth_size(1), requested_depth_size(2));
            
            if (enable_crop)
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

            imwrite(rescale(t_disparity).*255, colormap(flipud(cmap)), t_disp_path);
            imwrite(image_left, rgb_path);

            subplot(3,1,1)
            imshow(image_left_cropped);
            title('Image Left')

            subplot(3,1,2);
            imshow(depth);
            title('Depth');

            subplot(3,1,3);
            imshow(t_disparity,[],'Colormap',jet(4096));
            title('T Disparity Map');
            
            img_num = img_num + 1;   

            clear disparity t_disparity;

            drawnow;
            % check for interrupts
            key = uint8(get(f,'CurrentCharacter'));
            if(isempty(key))
                key=0;
            else
                disp('key pressed:');
                disp(key);
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
                end
                if (key == 99)
                    enable_crop = ~enable_crop;
                end
                if(key == 100) % press 'd' to reset to the default value
                    disp('reset to default');
                    mexZED('setCameraSettings', 'brightness', -1); % set auto value
                    roi = [0,0,image_size(1), image_size(2)];
                    mexZED('setCameraSettings', 'aec_agc_roi', roi, 2, 1); % set auto Gain/Exposure on full image
                end
                
                if(key == 114) % press 'r'  to use the auto Gain/Exposure on a defineded ROI
                    roi = [image_size(1)/4, image_size(2)/4, image_size(1)/2, image_size(2)/2];
                    mexZED('setCameraSettings', 'aec_agc_roi', roi);
                end
            end            
            set(f,'CurrentCharacter','0'); % reset pressed key
            break;
        else
            break;
        end
    end
    close(f)
end

% Make sure to call this function to free the memory before use this again
mexZED('close');
disp('========= END =========');