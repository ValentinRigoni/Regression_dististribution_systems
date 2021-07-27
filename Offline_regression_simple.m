clear; clc;
rng('default')

%% FOLDERS
Main_folder = pwd;
Network_folder = [Main_folder '\IEEE13'];

%% ***************************************************
% * Initialize OpenDSS
% ****************************************************
% Instantiate the OpenDSS Object
DSSObj = actxserver('OpenDSSEngine.DSS');
% Start up the Solver
if ~DSSObj.Start(0)
    disp('Unable to start the OpenDSS Engine')
    return
end
% Set up the Text, Circuit, and Solution Interfaces
DSSText = DSSObj.Text;
DSSCircuit = DSSObj.ActiveCircuit;
DSSSolution = DSSCircuit.Solution;

% Clears OpenDSS
DSSText.Command = 'clear';
DSSText.Command = ['set datapath=' Main_folder];
DSSText.Command ='Set DefaultBaseFrequency=50';

%% ****************************************************
% * Creates the OpenDSS circuit
% *****************************************************
DSSText.Command = ['Redirect ' Network_folder '/IEEE13Nodeckt.txt'];

DSSText.Command = 'set controlmode=static';
DSSText.Command = 'set mode=snapshot';
DSSSolution.Solve();

%% ****************************************************
% * Retrieve some of the network data
% *****************************************************
DSSElem = DSSCircuit.ActiveCktElement;
DSSBus = DSSCircuit.ActiveBus;

% Get Sets
Lines_set = DSSCircuit.Lines.AllNames;
Bus_set = DSSCircuit.AllBusNames;
Loads_set = DSSCircuit.Loads.AllNames;

% Get load data
peak_demand=zeros(size(Loads_set,1),1);
for i_load=1:size(Loads_set,1)
    DSSCircuit.Loads.Name = Loads_set{i_load};
    peak_demand(i_load) = DSSCircuit.Loads.kW;
end

% Get line data
Line_sending_bus=strings;
Line_receiving_bus=strings;
for i_line=1:size(Lines_set,1)
    DSSCircuit.Lines.Name = Lines_set{i_line};
    Line_sending_bus=[Line_sending_bus;DSSCircuit.Lines.Bus1];
    Line_receiving_bus=[Line_receiving_bus;DSSCircuit.Lines.Bus1];
end
Line_sending_bus(1) = [];
Line_receiving_bus(1) = [];

%% ****************************************************
% * Create the monitors
% *****************************************************
for i_line=1:size(Lines_set,1)
    line_name = Lines_set{i_line};
    % Measure voltages and currents
    DSSText.Command = ['New Monitor.' line_name '_VI_sending Line.' line_name ' Terminal=1 Mode=0 VIpolar=yes'];
    DSSText.Command = ['New Monitor.' line_name '_VI_receiving Line.' line_name ' Terminal=2 Mode=0 VIpolar=yes'];
    % Measure Active and reactive power flows
    DSSText.Command = ['New Monitor.' line_name '_PQ_sending Line.' line_name ' Terminal=1 Mode=1 ppolar=no'];
end
DSSMonitors=DSSCircuit.Monitors;

%% ****************************************************
% * Incorporate a Wind turbine and define points to read
% *****************************************************
DSSText.Command = 'New Load.WindTurbine Bus1=680 Phases=1 Model=1 kV=4.16 kW=0 kvar=0 Vminpu=0.8 Vmaxpu=1.2';
WindTurbine_rating=1000;

%% ****************************************************
% * Run some power flows and start mapping the grid
% *****************************************************
DSSCircuit.Loads.Name = 'WindTurbine';

Line_study = '632670';

P_flows= zeros(100,1);
Q_flows=P_flows;
Voltage_remote=P_flows;
Voltage_local=P_flows;
I_flows=P_flows;
ActivePower_values=P_flows;
TanPhi_values=P_flows;

count=0;
for i_ActivePower = 0.1:0.1:1.0
    for i_TanPhi = 0:tan(acos(0.95))/10:tan(acos(0.95))
        count=count+1;
        
        DSSCircuit.Loads.kW = - WindTurbine_rating*i_ActivePower;
        DSSCircuit.Loads.kvar = WindTurbine_rating*i_ActivePower * i_TanPhi;


        DSSText.Command ='Reset Monitors';
        DSSSolution.Solve()
        DSSMonitors.SampleAll() 
        DSSMonitors.SaveAll()
        
        % Read the monitors values
        % VI monitors
        % DSSMonitors.Header
        % V deg I degI
        % PQ monitors
        % P Q [kW & kvar]
        
        % P flow remote
        line_name = Line_study;
        DSSMonitors.Name = [line_name '_PQ_sending'];
        P_flows(count)=DSSMonitors.Channel(1);
        
        % Q flow remote
        line_name = Line_study;
        DSSMonitors.Name = [line_name '_PQ_sending'];
        Q_flows(count)=DSSMonitors.Channel(2);
        
        % I flow remote
        line_name = Line_study;
        DSSMonitors.Name = [line_name '_VI_sending'];
        I_flows(count)=DSSMonitors.Channel(3);

        %  V local
        DSSMonitors.Name = '671680_VI_receiving';
        Voltage_local(count)=DSSMonitors.Channel(1);
        
        %  V remote
        DSSMonitors.Name = '692675_VI_receiving';
        Voltage_remote(count)=DSSMonitors.Channel(1);
        
        ActivePower_values(count)=i_ActivePower;
        TanPhi_values(count)=i_TanPhi;
    end
end
