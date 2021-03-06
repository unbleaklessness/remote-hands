%% Manipulator setup:

robot = robotics.RigidBodyTree;

% Denavit-Hartenberg manipulator parameters:
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

% % Create serial connection:
% s = serial('/dev/ttyUSB8');
% set(s, 'BaudRate', 9600);
% fopen(s);

% Create TCP connection:
t = tcpip('0.0.0.0', 7247, 'NetworkRole', 'server');
fopen(t);
disp('New connection');

% t = tcpip('0.0.0.0', 7247, 'NetworkRole', 'server');
% set(t, 'InputBufferSize', 1000);
% fopen(t);

% Create inverse kinematics solver:
ik = robotics.InverseKinematics('RigidBodyTree', robot);
ik.RigidBodyTree = robot;

% Setup values needed to solver:
homeConf = homeConfiguration(robot);
effector = getTransform(robot, homeConf, 'node6', 'base'); % End effector transformation matrix.
target = [10 10 10]; % Desired end effector position.
weights = [0.01 0.01 0.01 1 1 1];

%% Main loop:

while true
    if t.BytesAvailable > 0
        data = fscanf(t); % Receive floating point values separated by spaces as string.
        splited = strsplit(data); % Split (by spaces) this string into an array of strings.
        
        % Check if received array has all 7 values:
        if (size(splited) < 7)
            continue;
        end
        
        % Convert array of strings to vector of reals:
        values = arrayfun(@(x) str2double(x), splited);
        
        % Discard wrong values:
        if values(1:3) == zeros(4)
            continue;
        end
        
        q = values(1:4); % Quaternion.
        acc = values(5:7); % Acceleration.
        acc = quatrotate(quatinv(q), acc); % Rotate acceleration by quaternion.
        acc = acc - [0 0 1]; % Subtract gravity from acceleration.
        
        % Discard wrong values (may appear after rotating by quaternion):
        if visnan(acc); continue; end
        
        target = target + (acc * 3); % Add acceleration to the desired position.
        
        % Prevent desired position going beyond manipulator working area:
        maxRange = 25;
        target = min(max(target, -maxRange), maxRange);
        
        % Update end effector transformation matrix with new desired position:
        effector(1:3, 4) = target;
        
        % Debug values:
%         fprintf('acceleration: %f %f %f \n', acc(1), acc(2), acc(3));
%         fprintf('target: %f %f %f \n', target(1), target(2), target(3));
        
        % Solve inverse kinematics:
        [ikSolution, ikInfo] = ik('node6', effector, weights, homeConf);
        
        % Update manipulator plot:
        show(robot, ikSolution);
        hold all;
        scatter3(target(1), target(2), target(3), 'r*', 'linewidth', 20);
        hold off;
        drawnow;
       
        disp(solutionPositions(ikSolution));
        
%         % Send inverse kinematics solution to manipulator via serial:
%         fprintf(s, prepare(solutionPositions(ikSolution)));
        
        flushinput(t);
    end
end

%% Clean up:

% Clean up TCP connection:
fclose(t); 
delete(t); 
clear t;

% Clean up serial connection:
fclose(s);
delete(s);
clear s;

%% Function definitions:

function f = solutionPositions(solution)
    % Get vector of positions from inverse kinematics solution. 
    f = arrayfun(@(x) x.JointPosition, solution);
end

function f = prepare(v)
    % Converts a vector to string for output to manipulator via serial.
    f = [fold(@(a, x) [a ' ' x], arrayfun(@(x) {num2str(x)}, v)) ' \n'];
end

function f = visnan(v)
    % Check if any value in a vector is NaN.
    flag = false;
    s = size(v);
    for i = 1:s(1)
        for j = 1:s(2)
            if isnan(v(i, j)) && ~flag; flag = true; end
        end
    end
    f = flag;
end