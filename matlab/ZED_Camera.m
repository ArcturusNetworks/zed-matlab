clc;
disp('========= ZED SDK PLUGIN =========');
disp('-- Retrieve Images and Depth --');
close all;
clear mex; clear functions; clear all;

% initial parameter structure, the same as sl::InitParameters
% values as enum number, defines in : sl/defines.hpp
% or from https://www.stereolabs.com/docs/api/structsl_1_1InitParameters.html

InitParameters.camera_resolution = 2; %HD720 = 2
InitParameters.camera_fps = 30;
InitParameters.coordinate_units = 2; %METER
InitParameters.depth_mode = 1; %PERFORMANCE
%InitParameters.svo_input_filename = './mySVOfile.svo'; % Enable SVO playback
InitParameters.depth_minimum_distance = 0.15;% Define maximum depth (in METER)
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
    
    % set colormap for saving transformed disparity maps
    cmap = jet(256);

    % Create Figure and wait for keyboard interruption to quit
    x0=10;
    y0=10;
    width=1000;
    height=2000;
    f = figure('name','ZED SDK : Images and Depth','NumberTitle','off','keypressfcn',@(obj,evt) 0);
    set(gcf,'position',[x0,y0,width,height])   
    % Setup runtime parameters
    RuntimeParameters.sensing_mode = 0; % STANDARD sensing mode
    
    key = 1;
    img_num = 0;
    % loop over frames, till Esc is pressed
    while (key ~= 27)
        % grab the current image and compute the depth
        result = mexZED('grab', RuntimeParameters);        
        if(strcmp(result,'SUCCESS'))
            % retrieve left image
            image_left = mexZED('retrieveImage', 2); %left gray
            % retrieve right image
            image_right = mexZED('retrieveImage', 1); %right
            % retrieve left image bgra
            image_left_rgb = mexZED('retrieveImage', 0); %left rgb
            
            % image timestamp
            im_ts = mexZED('getTimestamp', 0) 
                        
            % retrieve depth as a normalized image
            image_depth = mexZED('retrieveImage', 9); %depth
            % retrieve the real depth, resized
            depth = mexZED('retrieveMeasure', 1, requested_depth_size(1), requested_depth_size(2)); %depth
            % retrieve disparity measure
            disparity = mexZED('retrieveMeasure', 0, 1280, 720); %disparity

            %disparity = disparity * (1./96.0);
            %disparity = disparity * 255.0;

            % Convert nan/inf to 0
            disparity = double(disparity * -1.0);
            disparity(~(isfinite(disparity))) = 0;

            tic;
            disp('t_disp');
            t_disparity = t_disp(disparity);
            toc;
            
            % save transformed disparity variable (.mat format)
            %save('t_disparity.mat', 't_disparity');

            % save rgb and t_disp (with colormap) as png
            t_disp_path = ['./output/t_disp/' num2str(img_num) '.png'];
            rgb_path = ['./output/rgb/' num2str(img_num) '.png'];
            
            t_disparity = t_disparity * (1./96);
            t_disparity = t_disparity .* 255;

            %imwrite(t_disparity, colormap(cmap), t_disp_path, 'BitDepth', 8);
            %imwrite(t_disparity, colormap(cmap), t_disp_path);
            imwrite(t_disparity, colormap(flipud(cmap)), t_disp_path);
            %imwrite(image_left_rgb, rgb_path, 'BitDepth', 8);
            imwrite(image_left_rgb, rgb_path);

            %{
            cmap = jet(4096);
            % jetind = gray2ind(t_disparity, cmap); % gray2ind requires
            % 'Image Processing Toolbox'
            rgb = cat(3, t_disparity, t_disparity, t_disparity);
            jetind = rgb2ind(rgb, cmap);
            t_disparity_cmap = ind2rgb(jetind,cmap);
            %imwrite(t_disparity,'Colormap',jet(4096), img_name);
            %imwrite(t_disparity,jet(4096),img_name);
            %}


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

          
            
            img_num = img_num + 1;   

            clear disparity t_disparity t_disparity_cmap rgb jetind;

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