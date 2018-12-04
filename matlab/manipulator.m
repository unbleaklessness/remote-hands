%% SETUP MANIPULATOR:

robot = robotics.RigidBodyTree;

dhparams = [0   0	 0  0;
            0	0    1  0;
            1	pi/2 0	0;
            1   0	 0	0;
            1   0    0  0];

node1 = robotics.RigidBody('node1');
node2 = robotics.RigidBody('node2');
node3 = robotics.RigidBody('node3');
node4 = robotics.RigidBody('node4');
node5 = robotics.RigidBody('node5');

joint1 = robotics.Joint('joint1', 'revolute');
joint2 = robotics.Joint('joint2', 'revolute');
joint3 = robotics.Joint('joint3', 'revolute');
joint4 = robotics.Joint('joint4', 'revolute');
joint5 = robotics.Joint('joint5', 'revolute');

setFixedTransform(joint1, dhparams(1,:), 'dh');
setFixedTransform(joint2, dhparams(2,:), 'dh');
setFixedTransform(joint3, dhparams(3,:), 'dh');
setFixedTransform(joint4, dhparams(4,:), 'dh');
setFixedTransform(joint5, dhparams(5,:), 'dh');

node1.Joint = joint1;
node2.Joint = joint2;
node3.Joint = joint3;
node4.Joint = joint4;
node5.Joint = joint5;

addBody(robot, node1, robot.BaseName);
addBody(robot, node2, 'node1');
addBody(robot, node3, 'node2');
addBody(robot, node4, 'node3');
addBody(robot, node5, 'node4');

%% SETUP TCP CONNECTION

connection = tcpip('localhost', 7247);
set(connection, 'InputBufferSize', 1000);
fopen(connection);

while true
 while (get(connection, 'BytesAvailable') > 0) 
  received = fscanf(connection);
  disp(received)
 end 
end

%% Solve inverse kinematics:

ik = robotics.InverseKinematics('RigidBodyTree', robot);
ik.RigidBodyTree = robot;

homeConf = homeConfiguration(robot);
target = getTransform(robot, homeConf, 'node5', 'base');
target(1, 4) = -1.5;
target(2, 4) = -1.5;
target(3, 4) = 2;
weights = [0.01 0.01 0.01 1 1 1];

[ikSolution, ikInfo] = ik('node5', target, weights, homeConf);

%% OTHER:

% Show manipulator model:
showdetails(robot)
show(robot, ikSolution)

% Clean up TCP connection:
fclose(t); 
delete(t); 
clear t 
