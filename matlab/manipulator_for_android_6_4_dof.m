%% Main loop:

while true
    
    %% Manipulator setup:

    robot = robotics.RigidBodyTree;

    % Denavit-Hartenberg manipulator parameters:
    % dhparams = [0     pi/2  3.5   0;
    %             9.5	  0     0     0;
    %             9.5	  0     0     0;
    %             5     0     0     0;
    %             0     pi/2  0     0;
    %             10    0     0     0];

    dhparams = [0    pi/2  5    0;
                9.5	 0     0    0;
                7	 0     0    0;
                6.5  0     0    0;
                0    pi/2  0    0;
                4    0     0    0];

    % Setup manipulator nodes:
    node1 = robotics.RigidBody('node1');
    node2 = robotics.RigidBody('node2');
    node3 = robotics.RigidBody('node3');
    node4 = robotics.RigidBody('node4');
    node5 = robotics.RigidBody('node5');
    node6 = robotics.RigidBody('node6');

    % Setup manipulator joints:
    joint1 = robotics.Joint('joint1', 'revolute');
    joint2 = robotics.Joint('joint2', 'revolute');
    joint3 = robotics.Joint('joint3', 'revolute');
    joint4 = robotics.Joint('joint4', 'revolute');
    joint5 = robotics.Joint('joint5', 'revolute');
    joint6 = robotics.Joint('joint6', 'revolute');

    % Set position limits for joints:
    limit = [(-pi / 2) (pi / 2)];
    joint1.PositionLimits = limit;
    joint2.PositionLimits = limit;
    joint3.PositionLimits = limit;
    joint4.PositionLimits = limit;
    joint5.PositionLimits = limit;
    joint6.PositionLimits = limit;

    % Transform joints with DH parameters:
    setFixedTransform(joint1, dhparams(1,:), 'dh');
    setFixedTransform(joint2, dhparams(2,:), 'dh');
    setFixedTransform(joint3, dhparams(3,:), 'dh');
    setFixedTransform(joint4, dhparams(4,:), 'dh');
    setFixedTransform(joint5, dhparams(5,:), 'dh');
    setFixedTransform(joint6, dhparams(6,:), 'dh');

    % Assign joints to manipulator nodes:
    node1.Joint = joint1;
    node2.Joint = joint2;
    node3.Joint = joint3;
    node4.Joint = joint4;
    node5.Joint = joint5;
    node6.Joint = joint6;

    % Assemble manipulator:
    addBody(robot, node1, robot.BaseName);
    addBody(robot, node2, 'node1');
    addBody(robot, node3, 'node2');
    addBody(robot, node4, 'node3');
    addBody(robot, node5, 'node4');
    addBody(robot, node6, 'node5');

    %% Connections + initializations:

    is_serial = true;

    if is_serial

        % Find available serial ports:
        serials = seriallist;
        r_serial = '';
        serials_size = size(serials);
        for i = 1:serials_size(2)
            c_serial = serials(i);
            if contains(c_serial, 'USB')
                r_serial = c_serial;
                break;
            end
        end

        if strcmp(r_serial, '')
            error('Available serial port not found!');
        end

        % Create serial connection:
        s = serial(r_serial);
        set(s, 'BaudRate', 9600);
        fopen(s); 
    end

    % Create TCP connection:
    t = tcpip('0.0.0.0', 7247, 'NetworkRole', 'server');
    fopen(t);
    fprintf('New connection \n')

    % Create inverse kinematics solver:
    ik = robotics.InverseKinematics('RigidBodyTree', robot);
    ik.RigidBodyTree = robot;

    % Setup values needed to solver:
    homeConf = homeConfiguration(robot);
    effector = getTransform(robot, homeConf, 'node6', 'base'); % End effector transformation matrix.
    target = [0 0 0]; % Desired end effector position.
    origin = [10 10 10];
    weights = [0.01 0.01 0.01 1 1 1];

    trajectory = zeros(10000, 3);
    index = 1;

    %% Main loop:

    looping = true;

    while looping
        if t.BytesAvailable > 0
            data = fscanf(t); % Receive floating point values separated by spaces as string.

            fprintf('Data: %s \n', data)
            if contains(data, 'Restart')
                fprintf('Restart \n')
                looping = false;
                break
            end

            splited = strsplit(data); % Split (by spaces) this string into an array of strings.

            % Convert array of strings to vector of reals:
            values = arrayfun(@(x) str2double(x), splited);
            fprintf("Values: %f   %f   %f \n", values(1), values(2), values(3));

            target = (values(1:3) * 100) + origin; % Add acceleration to the desired position.

            trajectory(index, 1:3) = target;
            index = index + 1;

            % Prevent desired position going beyond manipulator working area:
            maxRange = 20;
            target = min(max(target, -maxRange), maxRange);

            % Update end effector transformation matrix with new desired position:
            effector(1:3, 4) = target;

            % Solve inverse kinematics:
            [ikSolution, ikInfo] = ik('node6', effector, weights, homeConf);

            positions = solutionPositions(ikSolution);
            homeConf = setPositionsToConfiguration(homeConf, positions);

            % Stop button:
            c = uicontrol;
            c.Style = 'pushbutton';
            c.String = 'Stop';
            c.Callback = 'looping = false;';

            % Update manipulator plot:
            show(robot, ikSolution);
            hold all;
            scatter3(target(1), target(2), target(3), 'r*', 'linewidth', 20);
            hold off;
            drawnow;

            if is_serial
                % Send inverse kinematics solution to manipulator via serial:
                message = prepare(solutionPositions(ikSolution));
                fprintf('Message: "%s" \n', message);
                fprintf(s, message);
            end

            flushinput(t);
        end
    end

    %% Plot trajectory:

    plot3(trajectory(:, 1), trajectory(:, 2), trajectory(:, 3), 'r')
    grid on;

    %% Clean up:

    % Clean up TCP connection:
    fclose(t); 
    delete(t); 
    clear t;

    if is_serial
        % Clean up serial connection:
        fclose(s);
        delete(s);
        clear s; 
    end 
end

%% Function definitions:

function f = prepare(v)
    % Converts a vector to string for output to manipulator via serial.
    f = [fold(@(a, x) [a ' ' x], arrayfun(@(x) {num2str(round(rad2deg(x), 4))}, v)) ' \n'];
end

function f = solutionPositions(solution)
    % Get vector of positions from inverse kinematics solution.
    r = arrayfun(@(x) x.JointPosition, solution);
    f = r(1, 1:4);
end

function f = setPositionsToConfiguration(configuration, positions)
    s = size(positions);
    for i = 1:s(2)
        configuration(i).JointPosition = positions(i);
    end
    f = configuration;
end