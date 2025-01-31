%% Spinning intensely 
clc;
clear;
close all;

% Constants
mass_satellite = 10.0;    % Mass of the satellite
inertia_satellite = 10.0; % Moment of inertia of the satellite
l1 = 1; l2 = 1;           % Link lengths
m1 = 5; m2 = 5;           % Link masses
Kp_end_effector = 50; Kd_end_effector = 10; % End-effector PD gains
thruster_force = 0.25;      % Small thrust boost
boundary_limit = 10;       % Bounds for the simulation space

% Simulation parameters
t_final = 20; dt = 0.1;
num_steps = t_final / dt;
time = 0:dt:t_final-dt; % Time vector

% Initial conditions: [x, y, theta, q1, q2, vx, vy, omega, dq1, dq2]
state = [0; 0; 0; deg2rad(30); deg2rad(-45); 0; 0; 0; 0; 0]; % Initial state

% Target position
target_position = [4; 4]; % 2D position
goal_tolerance = 0.1;

% Data storage for analysis and visualization
state_history = zeros(length(state), num_steps);
thrust_history = zeros(2, num_steps); % To track thruster activations
x_tilde_history = zeros(2, num_steps); % End-effector error
torque_history = zeros(1, num_steps); % Reaction torque from manipulator

for i = 1:num_steps
    % Store state
    state_history(:, i) = state;

    % Extract current values
    position = state(1:2);
    theta = state(3);
    q1 = state(4); q2 = state(5);
    velocity = state(6:7);
    omega = state(8);
    dq1 = state(9); dq2 = state(10);

    % Compute current end-effector position using forward kinematics
    R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
    p1 = position + R * [l1 * cos(q1); l1 * sin(q1)];
    end_effector = p1 + R * [l2 * cos(q1 + q2); l2 * sin(q1 + q2)];

    % Check if the end effector has reached the target
    if norm(end_effector - target_position) < goal_tolerance
        disp('End effector reached the target!');
        state_history = state_history(:, 1:i); % Trim unused steps
        thrust_history = thrust_history(:, 1:i); % Trim thrust history
        x_tilde_history = x_tilde_history(:, 1:i); % Trim error history
        torque_history = torque_history(:, 1:i); % Trim torques
        break;
    end

    % End-effector control
    x_tilde = end_effector - target_position; % Position error
    dx_tilde = R * ([l1 * -sin(q1), -l2 * sin(q1 + q2); l1 * cos(q1), l2 * cos(q1 + q2)] * [dq1; dq2]); % Velocity error
    x_tilde_history(:, i) = x_tilde; % Log position error

    % Jacobian matrix for the 2-link manipulator
    J = [
        -l1 * sin(q1) - l2 * sin(q1 + q2), -l2 * sin(q1 + q2);
        l1 * cos(q1) + l2 * cos(q1 + q2),  l2 * cos(q1 + q2)
    ];

    % PD control for the manipulator in end-effector space
    tau_manipulator = -J' * (Kp_end_effector * x_tilde + Kd_end_effector * dx_tilde);
    torque_history(i) = sum(tau_manipulator); % Log reaction torque

    % Dynamics of manipulator
    ddq = [0; 0]; % Manipulator dynamics placeholder (or compute as needed)

    % Update manipulator state
    dq1 = dq1 + ddq(1) * dt; q1 = q1 + dq1 * dt;
    dq2 = dq2 + ddq(2) * dt; q2 = q2 + dq2 * dt;

    % Update spacecraft dynamics (reaction torques from manipulator)
    domega_dt = sum(tau_manipulator) / inertia_satellite; % Angular acceleration
    omega = omega + domega_dt * dt; % Update angular velocity
    theta = theta + omega * dt; % Update orientation

    % Thruster control: Constant thrust toward target
    position_error = target_position - position; % Error in spacecraft position
    thrust = thruster_force * position_error / norm(position_error); % Normalize thrust vector
    thrust_history(:, i) = thrust; % Log thrust

    % Compute spacecraft dynamics
    dposition_dt = velocity; % Velocity affects position
    dvelocity_dt = thrust / mass_satellite; % Thrusters affect velocity
    position = position + dposition_dt * dt;
    velocity = velocity + dvelocity_dt * dt;

    % Update state vector
    state = [position; theta; q1; q2; velocity; omega; dq1; dq2];
end


% Visualization
figure;
hold on;
axis equal;
xlim([-boundary_limit, boundary_limit]);
ylim([-boundary_limit, boundary_limit]);
title('Spacecraft and 2-Link Manipulator with Thrusters');
xlabel('X Position');
ylabel('Y Position');

% Draw target as a circle
viscircles(target_position', goal_tolerance, 'Color', 'r', 'LineWidth', 0.5);

% Define spacecraft and manipulator shapes
spacecraft_shape = [-0.5, -0.5; 0.5, -0.5; 0.5, 0.5; -0.5, 0.5]'; % Square spacecraft
link1 = [0, 0; l1, 0]';
link2 = [0, 0; l2, 0]';

% Create plots
h_spacecraft = fill(spacecraft_shape(1, :), spacecraft_shape(2, :), 'b');
h_link1 = plot([0, 0], [0, 0], 'k', 'LineWidth', 2); % Link 1
h_link2 = plot([0, 0], [0, 0], 'k', 'LineWidth', 2); % Link 2

for k = 1:size(state_history, 2)
    % Extract states
    x = state_history(1, k);
    y = state_history(2, k);
    theta = state_history(3, k);
    q1 = state_history(4, k);
    q2 = state_history(5, k);

    % Rotate and translate spacecraft
    R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
    rotated_spacecraft = R * spacecraft_shape;
    set(h_spacecraft, 'XData', rotated_spacecraft(1, :) + x, 'YData', rotated_spacecraft(2, :) + y);

    % Forward kinematics for manipulator
    p1 = [x; y] + R * [l1*cos(q1); l1*sin(q1)];
    p2 = p1 + R * [l2*cos(q1 + q2); l2*sin(q1 + q2)];
    set(h_link1, 'XData', [x, p1(1)], 'YData', [y, p1(2)]);
    set(h_link2, 'XData', [p1(1), p2(1)], 'YData', [p1(2), p2(2)]);

    pause(0.05); % Control animation speed
end
hold off;

% Additional plots (e.g., position errors, torques, etc.)
figure;
plot(time, vecnorm(x_tilde_history, 2, 1));
title('End-Effector Error Over Time');
xlabel('Time (s)');
ylabel('Error (m)');

%% 
clc;
clear;
close all;

% Constants
mass_satellite = 10.0;    % Mass of the satellite
inertia_satellite = 10.0; % Moment of inertia of the satellite
l1 = 1; l2 = 1;           % Link lengths
m1 = 5; m2 = 5;           % Link masses
Kp_end_effector = 100;    % Increased Position Gain
Kd_end_effector = 50;     % Increased Damping Gain
thruster_force = 0.2;     % Increased thrust boost
boundary_limit = 10;      % Bounds for the simulation space

% Simulation parameters
t_final = 20; dt = 0.1;
num_steps = t_final / dt;
time = 0:dt:t_final-dt; % Time vector

% Initial conditions: [x, y, theta, q1, q2, vx, vy, omega, dq1, dq2]
state = [0; 0; 0; deg2rad(30); deg2rad(-45); 0; 0; 0; 0; 0]; % Initial state

% Target position
target_position = [4; 4]; % 2D position
goal_tolerance = 0.1;

% Data storage for analysis and visualization
state_history = zeros(length(state), num_steps);
thrust_history = zeros(2, num_steps); % To track thruster activations
x_tilde_history = zeros(2, num_steps); % End-effector error
torque_history = zeros(1, num_steps); % Reaction torque from manipulator

for i = 1:num_steps
    % Store state
    state_history(:, i) = state;

    % Extract current values
    position = state(1:2);
    theta = state(3);
    q1 = state(4); q2 = state(5);
    velocity = state(6:7);
    omega = state(8);
    dq1 = state(9); dq2 = state(10);

    % Compute current end-effector position using forward kinematics
    R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
    p1 = position + R * [l1 * cos(q1); l1 * sin(q1)];
    end_effector = p1 + R * [l2 * cos(q1 + q2); l2 * sin(q1 + q2)];

    % Check if the end effector has reached the target
    if norm(end_effector - target_position) < goal_tolerance
        disp('End effector reached the target!');
        state_history = state_history(:, 1:i); % Trim unused steps
        thrust_history = thrust_history(:, 1:i); % Trim thrust history
        x_tilde_history = x_tilde_history(:, 1:i); % Trim error history
        torque_history = torque_history(:, 1:i); % Trim torques
        break;
    end

    % End-effector control
    x_tilde = end_effector - target_position; % Position error
    dx_tilde = R * ([l1 * -sin(q1), -l2 * sin(q1 + q2); l1 * cos(q1), l2 * cos(q1 + q2)] * [dq1; dq2]); % Velocity error
    x_tilde_history(:, i) = x_tilde; % Log position error

    % Jacobian matrix for the 2-link manipulator
    J = [
        -l1 * sin(q1) - l2 * sin(q1 + q2), -l2 * sin(q1 + q2);
        l1 * cos(q1) + l2 * cos(q1 + q2),  l2 * cos(q1 + q2)
    ];

    % PD control for the manipulator in end-effector space
    tau_manipulator = -J' * (Kp_end_effector * x_tilde + Kd_end_effector * dx_tilde);
    torque_history(i) = sum(tau_manipulator); % Log reaction torque

    % Dynamics of manipulator
    ddq = [0; 0]; % Placeholder for manipulator dynamics

    % Update manipulator state
    dq1 = dq1 + ddq(1) * dt; q1 = q1 + dq1 * dt;
    dq2 = dq2 + ddq(2) * dt; q2 = q2 + dq2 * dt;

    % Update spacecraft dynamics (reaction torques from manipulator)
    domega_dt = sum(tau_manipulator) / inertia_satellite; % Angular acceleration
    omega = omega + domega_dt * dt; % Update angular velocity
    theta = theta + omega * dt; % Update orientation

    % Thruster control: Constant thrust toward target
    position_error = target_position - position; % Error in spacecraft position
    thrust = thruster_force * position_error / norm(position_error); % Normalize thrust vector
    thrust_history(:, i) = thrust; % Log thrust

    % Compute spacecraft dynamics
    dposition_dt = velocity; % Velocity affects position
    dvelocity_dt = thrust / mass_satellite; % Thrusters affect velocity
    position = position + dposition_dt * dt;
    velocity = velocity + dvelocity_dt * dt;

    % Update state vector
    state = [position; theta; q1; q2; velocity; omega; dq1; dq2];
end

% Visualization
figure;
hold on;
axis equal;
xlim([-boundary_limit, boundary_limit]);
ylim([-boundary_limit, boundary_limit]);
title('Spacecraft and 2-Link Manipulator with Thrusters');
xlabel('X Position');
ylabel('Y Position');

% Draw the target as a circle
viscircles(target_position', goal_tolerance, 'Color', 'r', 'LineWidth', 0.5);

% Define spacecraft and manipulator shapes
spacecraft_shape = [-0.5, -0.5; 0.5, -0.5; 0.5, 0.5; -0.5, 0.5]'; % Square spacecraft
link1 = [0, 0; l1, 0]';
link2 = [0, 0; l2, 0]';

% Create plots
h_spacecraft = fill(spacecraft_shape(1, :), spacecraft_shape(2, :), 'b');
h_link1 = plot([0, 0], [0, 0], 'k', 'LineWidth', 2); % Link 1
h_link2 = plot([0, 0], [0, 0], 'k', 'LineWidth', 2); % Link 2

for k = 1:size(state_history, 2)
    % Extract states
    x = state_history(1, k);
    y = state_history(2, k);
    theta = state_history(3, k);
    q1 = state_history(4, k);
    q2 = state_history(5, k);

    % Rotate and translate spacecraft
    R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
    rotated_spacecraft = R * spacecraft_shape;
    set(h_spacecraft, 'XData', rotated_spacecraft(1, :) + x, 'YData', rotated_spacecraft(2, :) + y);

    % Forward kinematics for manipulator
    p1 = [x; y] + R * [l1*cos(q1); l1*sin(q1)];
    p2 = p1 + R * [l2*cos(q1 + q2); l2*sin(q1 + q2)];
    set(h_link1, 'XData', [x, p1(1)], 'YData', [y, p1(2)]);
    set(h_link2, 'XData', [p1(1), p2(1)], 'YData', [p1(2), p2(2)]);

    pause(0.05); % Control animation speed
end
hold off;

% Additional plots
figure;
plot(time, vecnorm(x_tilde_history, 2, 1));
title('End-Effector Error Over Time');
xlabel('Time (s)');
ylabel('Error (m)');

%% Coupled Manipulator and space craft dynamics
clc;
clear;
close all;

% Constants
mass_satellite = 10.0;    % Mass of the satellite
inertia_satellite = 10.0; % Moment of inertia of the satellite
l1 = 1; l2 = 1;           % Link lengths
m1 = 5; m2 = 5;           % Link masses
Kp_end_effector = 100;    % End-effector proportional gain (increased)
Kd_end_effector = 50;     % End-effector damping gain
thruster_force = 0.2;     % Thruster boost
boundary_limit = 10;      % Bounds for the simulation space

% Simulation parameters
t_final = 20; dt = 0.1;
num_steps = t_final / dt;
time = 0:dt:t_final-dt; % Time vector

% Initial conditions: [x, y, theta, q1, q2, vx, vy, omega, dq1, dq2]
state = [0; 0; 0; deg2rad(30); deg2rad(-45); 0; 0; 0; 0; 0]; % Initial state

% Target position
target_position = [4; 4]; % 2D position
goal_tolerance = 0.1;

% Data storage for analysis and visualization
state_history = zeros(length(state), num_steps);
x_tilde_history = zeros(2, num_steps); % End-effector error
torque_history = zeros(1, num_steps); % Reaction torque from manipulator

for i = 1:num_steps
    % Store state
    state_history(:, i) = state;

    % Extract current values
    position = state(1:2);
    phi = state(3); % Current orientation
    q1 = state(4); q2 = state(5);
    velocity = state(6:7);
    omega = state(8);
    dq1 = state(9); dq2 = state(10);

    % Compute current end-effector position using forward kinematics
    R = [cos(phi), -sin(phi); sin(phi), cos(phi)];
    p1 = position + R * [l1 * cos(q1); l1 * sin(q1)];
    end_effector = p1 + R * [l2 * cos(q1 + q2); l2 * sin(q1 + q2)];

    % Check if the end effector has reached the target
    if norm(end_effector - target_position) < goal_tolerance
        disp('End effector reached the target!');
        state_history = state_history(:, 1:i); % Trim unused steps
        x_tilde_history = x_tilde_history(:, 1:i); % Trim error history
        torque_history = torque_history(:, 1:i); % Trim torques
        break;
    end

    % End-effector control
    x_tilde = end_effector - target_position; % Position error
    dx_tilde = R * ([l1 * -sin(q1), -l2 * sin(q1 + q2); l1 * cos(q1), l2 * cos(q1 + q2)] * [dq1; dq2]); % Velocity error
    x_tilde_history(:, i) = x_tilde; % Log position error

    % Jacobian matrix for the 2-link manipulator
    J = [
        -l1 * sin(q1) - l2 * sin(q1 + q2), -l2 * sin(q1 + q2);
        l1 * cos(q1) + l2 * cos(q1 + q2),  l2 * cos(q1 + q2)
    ];

    % PD control for the manipulator in end-effector space
    tau_manipulator = -J' * (Kp_end_effector * x_tilde + Kd_end_effector * dx_tilde);

    % Reaction torque from manipulator affects spacecraft
    tau_reaction = -sum(tau_manipulator); % Reaction torque on spacecraft
    torque_history(i) = tau_reaction;

    % Dynamics of manipulator
    H11 = m1*0.5^2 + m2*(l1^2 + l2^2) + 2*m2*l1*l2*cos(q2) + inertia_satellite;
    H22 = m2*l2^2 + inertia_satellite;
    H12 = m2*l1*l2*cos(q2);
    H = [H11, H12; H12, H22];

    % Velocity-dependent forces (Coriolis)
    h = -m2 * l1 * l2 * sin(q2);
    C = [h * dq2, h * (dq1 + dq2); -h * dq1, 0];

    % Joint accelerations
    ddq = H \ (tau_manipulator - C * [dq1; dq2]);

    % Update manipulator state
    dq1 = dq1 + ddq(1) * dt; q1 = q1 + dq1 * dt;
    dq2 = dq2 + ddq(2) * dt; q2 = q2 + dq2 * dt;

    % Update spacecraft dynamics using manipulator reaction torque
    domega_dt = tau_reaction / inertia_satellite; % Angular acceleration
    omega = omega + domega_dt * dt; % Update angular velocity
    phi = phi + omega * dt; % Update orientation

    % Thruster control: Constant thrust toward target
    position_error = target_position - position; % Error in spacecraft position
    thrust = thruster_force * position_error / norm(position_error); % Normalize thrust vector

    % Compute spacecraft translational dynamics
    dposition_dt = velocity; % Velocity affects position
    dvelocity_dt = thrust / mass_satellite; % Thrusters affect velocity
    position = position + dposition_dt * dt;
    velocity = velocity + dvelocity_dt * dt;

    % Update state vector
    state = [position; phi; q1; q2; velocity; omega; dq1; dq2];
end

% Visualization
figure;
hold on;
axis equal;
xlim([-boundary_limit, boundary_limit]);
ylim([-boundary_limit, boundary_limit]);
title('Spacecraft and 2-Link Manipulator with Reaction Control');
xlabel('X Position');
ylabel('Y Position');

% Draw the target as a circle
viscircles(target_position', goal_tolerance, 'Color', 'r', 'LineWidth', 0.5);

% Define spacecraft and manipulator shapes
spacecraft_shape = [-0.5, -0.5; 0.5, -0.5; 0.5, 0.5; -0.5, 0.5]'; % Square spacecraft
link1 = [0, 0; l1, 0]';
link2 = [0, 0; l2, 0]';

% Create plots
h_spacecraft = fill(spacecraft_shape(1, :), spacecraft_shape(2, :), 'b');
h_link1 = plot([0, 0], [0, 0], 'k', 'LineWidth', 2); % Link 1
h_link2 = plot([0, 0], [0, 0], 'k', 'LineWidth', 2); % Link 2

for k = 1:size(state_history, 2)
    % Extract states
    x = state_history(1, k);
    y = state_history(2, k);
    phi = state_history(3, k);
    q1 = state_history(4, k);
    q2 = state_history(5, k);

    % Rotate and translate spacecraft
    R = [cos(phi), -sin(phi); sin(phi), cos(phi)];
    rotated_spacecraft = R * spacecraft_shape;
    set(h_spacecraft, 'XData', rotated_spacecraft(1, :) + x, 'YData', rotated_spacecraft(2, :) + y);

    % Forward kinematics for manipulator
    p1 = [x; y] + R * [l1*cos(q1); l1*sin(q1)];
    p2 = p1 + R * [l2*cos(q1 + q2); l2*sin(q1 + q2)];
    set(h_link1, 'XData', [x, p1(1)], 'YData', [y, p1(2)]);
    set(h_link2, 'XData', [p1(1), p2(1)], 'YData', [p1(2), p2(2)]);

    pause(0.05); % Control animation speed
end
hold off;

% Additional plots
figure;
plot(time, vecnorm(x_tilde_history, 2, 1));
title('End-Effector Error Over Time');
xlabel('Time (s)');
ylabel('Error (m)');

%% WORKING!!! Coupled Manipulator + S/C dynamics with PD control
clc;
clear;
close all;

% Constants
mass_satellite = 10.0;    % Mass of the satellite
inertia_satellite = 10.0; % Moment of inertia of the satellite
l1 = 1; l2 = 1;           % Link lengths
m1 = 5; m2 = 5;           % Link masses
Kp_end_effector = 100;    % End-effector proportional gain
Kd_end_effector = 50;     % End-effector damping gain
thruster_force = 0.2;     % Thruster boost
boundary_limit = 10;      % Bounds for the simulation space

% Limits
q_limit = deg2rad(150);    % Maximum joint angle limit
dq_limit = deg2rad(50);    % Maximum joint velocity limit
omega_limit = 1;           % Maximum satellite angular velocity

% Regularization factor for Jacobian (to avoid singularities)
regularization_factor = 1e-6;

% Simulation parameters
t_final = 100; dt = 0.1;
num_steps = t_final / dt;
time = 0:dt:t_final-dt; % Time vector

% Initial conditions: [x, y, theta, q1, q2, vx, vy, omega, dq1, dq2]
state = [0; 0; 0; deg2rad(30); deg2rad(-45); 0; 0; 0; 0; 0]; % Initial state

% Target position
target_position = [4; 4]; % 2D position
goal_tolerance = 0.1;

% Data storage for analysis and visualization
state_history = zeros(length(state), num_steps);
x_tilde_history = zeros(2, num_steps); % End-effector error

for i = 1:num_steps
    % Store state
    state_history(:, i) = state;

    % Extract current values
    position = state(1:2);
    phi = state(3); % Current orientation
    q1 = state(4); q2 = state(5);
    velocity = state(6:7);
    omega = state(8);
    dq1 = state(9); dq2 = state(10);

    % Compute current end-effector position using forward kinematics
    R = [cos(phi), -sin(phi); sin(phi), cos(phi)];
    p1 = position + R * [l1 * cos(q1); l1 * sin(q1)];
    end_effector = p1 + R * [l2 * cos(q1 + q2); l2 * sin(q1 + q2)];

    % Check if the end effector has reached the target
    if norm(end_effector - target_position) < goal_tolerance
        disp('End effector reached the target!');
        state_history = state_history(:, 1:i); % Trim unused steps
        x_tilde_history = x_tilde_history(:, 1:i); % Trim error history
        break;
    end

    % End-effector control
    x_tilde = end_effector - target_position; % Position error
    dx_tilde = R * ([l1 * -sin(q1), -l2 * sin(q1 + q2); l1 * cos(q1), l2 * cos(q1 + q2)] * [dq1; dq2]); % Velocity error
    x_tilde_history(:, i) = x_tilde; % Log position error

    % Jacobian matrix for the 2-link manipulator
    J = [
        -l1 * sin(q1) - l2 * sin(q1 + q2), -l2 * sin(q1 + q2);
        l1 * cos(q1) + l2 * cos(q1 + q2),  l2 * cos(q1 + q2)
    ];

    % Add regularization to the Jacobian
    J_reg = J' * J + regularization_factor * eye(2);

    % PD control for the manipulator in end-effector space
    tau_manipulator = -J_reg \ J' * (Kp_end_effector * x_tilde + Kd_end_effector * dx_tilde);

    % Reaction torque from manipulator affects spacecraft
    tau_reaction = -sum(tau_manipulator); % Reaction torque on spacecraft

    % Dynamics of manipulator
    H11 = m1 * 0.5^2 + m2 * (l1^2 + l2^2) + 2 * m2 * l1 * l2 * cos(q2) + inertia_satellite;
    H22 = m2 * l2^2 + inertia_satellite;
    H12 = m2 * l1 * l2 * cos(q2);
    H = [H11, H12; H12, H22];

    % Velocity-dependent forces (Coriolis)
    h = -m2 * l1 * l2 * sin(q2);
    C = [h * dq2, h * (dq1 + dq2); -h * dq1, 0];

    % Joint accelerations
    ddq = H \ (tau_manipulator - C * [dq1; dq2]);

    % Update manipulator state with limits
    dq1 = max(min(dq1 + ddq(1) * dt, dq_limit), -dq_limit);
    dq2 = max(min(dq2 + ddq(2) * dt, dq_limit), -dq_limit);
    q1 = max(min(q1 + dq1 * dt, q_limit), -q_limit);
    q2 = max(min(q2 + dq2 * dt, q_limit), -q_limit);

    % Update spacecraft dynamics using manipulator reaction torque
    domega_dt = tau_reaction / inertia_satellite; % Angular acceleration
    omega = max(min(omega + domega_dt * dt, omega_limit), -omega_limit); % Update angular velocity
    phi = phi + omega * dt; % Update orientation

    % Thruster control: Constant thrust toward target
    position_error = target_position - position; % Error in spacecraft position
    thrust = thruster_force * position_error / max(norm(position_error), 1e-6); % Normalize thrust vector

    % Compute spacecraft translational dynamics
    dposition_dt = velocity; % Velocity affects position
    dvelocity_dt = thrust / mass_satellite; % Thrusters affect velocity
    position = position + dposition_dt * dt;
    velocity = velocity + dvelocity_dt * dt;

    % Update state vector
    state = [position; phi; q1; q2; velocity; omega; dq1; dq2];
end

% Visualization
figure;
hold on;
axis equal;
xlim([-boundary_limit, boundary_limit]);
ylim([-boundary_limit, boundary_limit]);
title('Spacecraft and 2-Link Manipulator with Reaction Control');
xlabel('X Position');
ylabel('Y Position');

% Draw the target as a circle
viscircles(target_position', goal_tolerance, 'Color', 'r', 'LineWidth', 0.5);

% Define spacecraft and manipulator shapes
spacecraft_shape = [-0.5, -0.5; 0.5, -0.5; 0.5, 0.5; -0.5, 0.5]'; % Square spacecraft
link1 = [0, 0; l1, 0]';
link2 = [0, 0; l2, 0]';

% Create plots
h_spacecraft = fill(spacecraft_shape(1, :), spacecraft_shape(2, :), 'b');
h_link1 = plot([0, 0], [0, 0], 'k', 'LineWidth', 2); % Link 1
h_link2 = plot([0, 0], [0, 0], 'k', 'LineWidth', 2);

for k = 1:size(state_history, 2)
    % Extract states
    x = state_history(1, k);
    y = state_history(2, k);
    phi = state_history(3, k);
    q1 = state_history(4, k);
    q2 = state_history(5, k);

    % Rotate and translate spacecraft
    R = [cos(phi), -sin(phi); sin(phi), cos(phi)];
    rotated_spacecraft = R * spacecraft_shape;
    set(h_spacecraft, 'XData', rotated_spacecraft(1, :) + x, 'YData', rotated_spacecraft(2, :) + y);

    % Forward kinematics for manipulator
    p1 = [x; y] + R * [l1*cos(q1); l1*sin(q1)];
    p2 = p1 + R * [l2*cos(q1 + q2); l2*sin(q1 + q2)];
    set(h_link1, 'XData', [x, p1(1)], 'YData', [y, p1(2)]);
    set(h_link2, 'XData', [p1(1), p2(1)], 'YData', [p1(2), p2(2)]);

    pause(0.05); % Control animation speed
end

hold off;

% Adjust time vector to match the size of x_tilde_history
time_trimmed = time(1:size(x_tilde_history, 2));

% Plot the end-effector error over time
figure;
plot(time_trimmed, vecnorm(x_tilde_history, 2, 1));
title('End-Effector Error Over Time');
xlabel('Time (s)');
ylabel('Error (m)');

