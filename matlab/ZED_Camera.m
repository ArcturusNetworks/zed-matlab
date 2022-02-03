clc;
disp('========= ZED SDK PLUGIN =========');
disp('-- Retrieve Images and Depth --');
close all; clear mex; clear functions; clear all;

% initial parameter structure, the same as sl::InitParameters
% values as enum number, defines in : sl/defines.hpp
% or from https://www.stereolabs.com/docs/api/structsl_1_1InitParameters.html

InitParameters.camera_resolution = 1; %0=2k 1=1080P 2=HD720P
InitParameters.camera_fps = 60;
InitParameters.coordinate_units = 2; %0=MM 1=CM 2=M 3=IN 4=FT
InitParameters.depth_mode = 1; %0=NONE 1=PERFORMANCE 2=QUALITY 3=ULTRA
InitParameters.svo_input_filename = 'HD720_SN35552717_17-00-14.svo'; % Enable SVO playback
%InitParameters.depth_minimum_distance = 0;% Define maximum dept
%InitParameters.depth_maximum_distance = 7;% Define maximum dept
result = mexZED('open', InitParameters);

if(strcmp(result,'SUCCESS')) % the Camera is open
    
    % basic informations
    camInfo = mexZED('getCameraInformation');
    image_size = [camInfo.left_cam.width camInfo.left_cam.height];
    
    requested_depth_size = [720 404];
    %requested_depth_size = [1280 720];
    
    % (optional) Get number of frames (if SVO)
    nbFrame = mexZED('getSVONumberOfFrames');    
    
    % set colormap for saving transformed disparity maps
    cmap = jet(256);

    % Create Figure and wait for keyboard interruption to quit
    x0=0;
    y0=0;
    width=500;
    height=800;
    f = figure('name','ZED SDK : Images and Depth','NumberTitle','off','keypressfcn',@(obj,evt) 0);
    set(gcf,'position',[x0,y0,width,height])   
    % Setup runtime parameters
    RuntimeParameters.sensing_mode = 0; % STANDARD sensing mode

    %crop_rect=[280,70,920,620];
    %crop_rect=[280,70,400,400];

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
                crop_rect = centerCropWindow2d(size(image_left), [400 400]);
                [image_left, rect] = imcrop(image_left, crop_rect);
                [depth, rect] = imcrop(depth, crop_rect);
                [disparity, rect] = imcrop(disparity, crop_rect);
            end
            % Convert nan/inf to 0
            disparity = double(disparity * -1.0);
            disparity(~(isfinite(disparity))) = 0;

            %tic;
            t_disparity = t_disp(disparity);
            %toc;

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
            imshow(t_disparity,[],'Colormap',jet(4096));
            colorbar;
            title('T Disparity Map');
            
            img_num = img_num + 1;   

            clear disparity t_disparity;

            drawnow;

            % check for interrupts
            key = uint8(get(f,'CurrentCharacter'));
            if (isempty(key))
                key=0
            else
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
                if (key == 28)
                    position = mexZED('getSVOPosition') - 50;
                    position = max(0, position);
                    mexZED('setSVOPosition', position)
                end
                if (key == 29)
                    position = mexZED('getSVOPosition') + 50;
                    position = min(nbFrame, position);
                    mexZED('setSVOPosition', position)
                end
                if (key == 'c')
                    enable_crop = ~enable_crop;
                end
                if(key == 100) % press 'd' to reset to the default value
                    disp('reset to default');
                    mexZED('setCameraSettings', 'brightness', -1); % set auto value
                    roi = [0,0,image_size(1), image_size(2)];
                    mexZED('setCameraSettings', 'aec_agc_roi', roi, 2, 1); % set auto Gain/Exposure on full image
                end
                
                if(key == 'r') % press 'r'  to use the auto Gain/Exposure on a defineded ROI
                    roi = [image_size(1)/4, image_size(2)/4, image_size(1)/2, image_size(2)/2];
                    mexZED('setCameraSettings', 'aec_agc_roi', roi);
                end

                if (key == 's')
                    imwrite(rescale(t_disparity).*255, colormap(flipud(cmap)), t_disp_path);
                    imwrite(image_left, rgb_path);
                    fprintf("images saved\n");
                end
    
                if (key == 32) % space bar
                    waitforbuttonpress;
                end
                if (key == 27 || key == 'q')
                    break;
                end
            end
            set(f,'CurrentCharacter','0'); % reset pressed key
        else
            break;
        end
    end
    close(f)
end

% Make sure to call this function to free the memory before use this again
mexZED('close');
disp('========= END =========');