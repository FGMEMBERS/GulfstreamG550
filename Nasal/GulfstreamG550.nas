var FDM=0;
var FDMjsb = 0;
var ViewNum=0;
var SndIn = props.globals.getNode("/sim/sound/Cvolume",1);
var SndOut = props.globals.getNode("/sim/sound/Ovolume",1);
var Grd_Idle=1;
var Annun = props.globals.getNode("instrumentation/annunciators",1);
var MstrWarn =Annun.getNode("master-warning",1);
var MstrCaution = Annun.getNode("master-caution",1);
var PWR2 =0;
var counter=0;
aircraft.livery.init("Aircraft/GulfstreamG550/Models/Liveries");

#tire rotation per minute by circumference/groundspeed#
TireSpeed = {
    new : func(number){
        m = { parents : [TireSpeed] };
            m.num=number;
            m.circumference=[];
            m.tire=[];
            m.rpm=[];
            for(var i=0; i<m.num; i+=1) {
                var diam =arg[i];
                var circ=diam * math.pi;
                append(m.circumference,circ);
                append(m.tire,props.globals.initNode("gear/gear["~i~"]/tire-rpm",0,"DOUBLE"));
                append(m.rpm,0);
            }
        m.count = 0;
        return m;
    },
    #### calculate and write rpm ###########
    get_rotation: func (fdm1){
        var speed=0;
        if(getprop("gear/gear["~me.count~"]/position-norm")==0){
            return;
        }
        if(fdm1=="yasim"){ 
            speed =getprop("gear/gear["~me.count~"]/rollspeed-ms") or 0;
            speed=speed*60;
            }elsif(fdm1=="jsb"){
                speed =getprop("fdm/jsbsim/gear/unit["~me.count~"]/wheel-speed-fps") or 0;
                speed=speed*18.288;
            }
        var wow = getprop("gear/gear["~me.count~"]/wow");
        if(wow){
            me.rpm[me.count] = speed / me.circumference[me.count];
        }else{
            if(me.rpm[me.count] > 0) me.rpm[me.count]=me.rpm[me.count]*0.95;
        }
        me.tire[me.count].setValue(me.rpm[me.count]);
        me.count+=1;
        if(me.count>=me.num)me.count=0;
    },
};


#var tire=TireSpeed.new(# of gear,diam[0],diam[1],diam[2], ...);
var tire=TireSpeed.new(3,0.430,0.615,0.615);

#Jet Engine Helper class 
# ie: var Eng = JetEngine.new(engine number);
var JetEngine = {
    new : func(eng_num){
        m = { parents : [JetEngine]};
        m.ITTlimit=8.9;
        m.fdensity = getprop("consumables/fuel/tank/density-ppg");
        if(m.fdensity ==nil)m.fdensity=6.72;
        m.eng = props.globals.getNode("engines/engine["~eng_num~"]",1);
        m.running = m.eng.getNode("running",1);
        m.running.setBoolValue(0);
        m.itt=m.eng.getNode("itt-norm");
        m.itt_c=m.eng.getNode("itt-celcius",1);
        m.itt_c.setDoubleValue(0);
        m.n1 = m.eng.getNode("n1",1);
        m.n2 = m.eng.getNode("n2",1);
        m.fan = m.eng.getNode("fan",1);
        m.fan.setDoubleValue(0);
        m.cycle_up = m.eng.getNode("start-cycle",1);
        m.cycle_up.setBoolValue(0);
        m.turbine = m.eng.getNode("turbine",1);
        m.turbine.setDoubleValue(0);
        m.throttle_lever = props.globals.getNode("controls/engines/engine["~eng_num~"]/throttle-lever",1);
        m.throttle_lever.setDoubleValue(0);
        m.throttle = props.globals.getNode("controls/engines/engine["~eng_num~"]/throttle",1);
        m.throttle.setDoubleValue(0);
        m.ignition = props.globals.getNode("controls/engines/engine["~eng_num~"]/ignition",1);
        m.cutoff = props.globals.getNode("controls/engines/engine["~eng_num~"]/cutoff",1);
        m.cutoff.setBoolValue(1);
        m.fuel_out = props.globals.getNode("engines/engine["~eng_num~"]/out-of-fuel",1);
        m.fuel_out.setBoolValue(0);
        m.starter = props.globals.getNode("controls/engines/engine["~eng_num~"]/starter",1);
        m.fuel_pph=m.eng.getNode("fuel-flow_pph",1);
        m.fuel_pph.setDoubleValue(0);
        m.fuel_gph=m.eng.getNode("fuel-flow-gph",1);
        m.hpump=props.globals.getNode("systems/hydraulics/pump-psi["~eng_num~"]",1);
        m.hpump.setDoubleValue(0);
    return m;
    },
#### update ####
    update : func{
        if(me.fuel_out.getBoolValue())me.cutoff.setBoolValue(1);
        if(!me.ignition.getBoolValue())me.cutoff.setBoolValue(1);
        if(!me.cutoff.getBoolValue()){
        me.fan.setValue(me.n1.getValue());
        me.turbine.setValue(me.n2.getValue());
        if()me.throttle.setValue(me.throttle.getValue);
        var thr = me.throttle.getValue();
        if(getprop("controls/engines/grnd_idle"))thr *=0.92;
        me.throttle_lever.setValue(thr);
        }else{
            me.throttle_lever.setValue(0);
            if(me.starter.getBoolValue())me.cycle_up.setValue(me.ignition.getBoolValue());
            if(me.cycle_up.getBoolValue()){
                me.spool_up(15);
            }else{
                var tmprpm = me.fan.getValue();
                if(tmprpm > 0.0){
                    tmprpm -= getprop("sim/time/delta-sec") * 2;
                    me.fan.setValue(tmprpm);
                    me.turbine.setValue(tmprpm);
                }
            }
        }
    me.fuel_pph.setValue(me.fuel_gph.getValue()*me.fdensity);
    var hpsi =me.fan.getValue();
    if(hpsi>60)hpsi = 60;
    me.hpump.setValue(hpsi);
    me.itt_c.setValue(me.fan.getValue() * me.ITTlimit);
    },

    spool_up : func(scnds){
        if(!me.cutoff.getBoolValue()){
        return;
        }else{
        var n1=me.n1.getValue() ;
        var n1factor = n1/scnds;
        var n2=me.n2.getValue() ;
        var n2factor = n2/scnds;
        var tmprpm = me.fan.getValue();
            tmprpm += getprop("sim/time/delta-sec") * n1factor;
            var tmprpm2 = me.turbine.getValue();
            tmprpm2 += getprop("sim/time/delta-sec") * n2factor;
            me.fan.setValue(tmprpm);
            me.turbine.setValue(tmprpm2);
            if(tmprpm >= me.n1.getValue()){
            me.cutoff.setBoolValue(0);
            me.cycle_up.setBoolValue(0);
            }
        }
    },
};

aircraft.light.new("instrumentation/annunciators", [0.5, 0.5], MstrCaution);
var cabin_door = aircraft.door.new("/controls/cabin-door", 2);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10,1);
var LHeng= JetEngine.new(0);
var RHeng= JetEngine.new(1);
var Grd_Idle=props.globals.getNode("controls/engines/grnd-idle",1);
Grd_Idle.setBoolValue(1);


#######################################
setlistener("/sim/signals/fdm-initialized", func {
    fdm_init();
    Shutdown();
    settimer(update_systems,2);
});

setlistener("/sim/signals/reinit", func {
    fdm_init();
    Shutdown();
});

setlistener("/sim/crashed", func(cr){
    if(cr.getBoolValue()){
        Shutdown();
    }
},1,0);

var fdm_init = func(){
    SndIn.setDoubleValue(0.75);
    SndOut.setDoubleValue(0.15);
    MstrWarn.setBoolValue(0);
    MstrCaution.setBoolValue(0);
    if(getprop("/sim/flight-model")=="jsb"){FDMjsb=1;}
    setprop("/sim/model/start-idling",0);
    setprop("controls/engines/N1-limit",90.0);
}

setlistener("/gear/gear[1]/wow", func(ww){
    if(ww.getBoolValue()){
        FHmeter.stop();
        Grd_Idle.setBoolValue(1);
    }else{
        FHmeter.start();
        Grd_Idle.setBoolValue(0);
    }
},0,0);

setlistener("sim/model/autostart", func(strt){
    if(strt.getBoolValue()){
        Startup();
    }else{
        Shutdown();
    }
},0,0);

controls.gearDown = func(v) {
    if (v < 0) {
        if(!getprop("gear/gear[1]/wow"))setprop("/controls/gear/gear-down", 0);
    } elsif (v > 0) {
      setprop("/controls/gear/gear-down", 1);
    }
}

setlistener("/sim/current-view/internal", func(vw){
    if(!vw.getValue()){
    SndIn.setDoubleValue(0.75);
    SndOut.setDoubleValue(0.10);
    }else{
    SndIn.setDoubleValue(0.10);
    SndOut.setDoubleValue(0.75);
    }
},1,0);

setlistener("/controls/gear/antiskid", func(as){
    var test=as.getBoolValue();
    if(!test){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("antiskid").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("antiskid").setBoolValue(0);
    }
},0,0);

setlistener("/sim/freeze/fuel", func(ffr){
    var test=ffr.getBoolValue();
    if(test){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("fuel-gauge").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("fuel-gauge").setBoolValue(0);
    }
},0,0);


var annunciators_loop = func{
setprop("/instrumentation/annunciators/LHign",LHeng.cycle_up.getBoolValue());
setprop("/instrumentation/annunciators/fuel-boost",LHeng.cycle_up.getBoolValue());
setprop("/instrumentation/annunciators/RHign",RHeng.cycle_up.getBoolValue());
setprop("/instrumentation/annunciators/fuel-boost",RHeng.cycle_up.getBoolValue());

var Tfuel = getprop("/consumables/fuel/total-fuel-lbs");
if(Tfuel != nil){
if( Tfuel< 400){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("fuel-lo").setBoolValue(1 * PWR2);
}else{
        Annun.getNode("fuel-lo").setBoolValue(0);
        }
    }

if(getprop("/gear/gear[0]/position-norm") == 1.0){
    Annun.getNode("gear-N").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gear-N").setBoolValue(0);
}

if(getprop("/gear/gear[1]/position-norm") == 1.0){
    Annun.getNode("gear-L").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gear-L").setBoolValue(0);
}

if(getprop("/gear/gear[2]/position-norm") == 1.0){
    Annun.getNode("gear-R").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gear-R").setBoolValue(0);
}



if(getprop("/controls/electric/engine[0]/generator") == 0){
    MstrWarn.setBoolValue(1 * PWR2);
    Annun.getNode("gen-off").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gen-off").setBoolValue(0);
}

if(getprop("/controls/electric/engine[1]/generator") == 0){
    MstrWarn.setBoolValue(1 * PWR2);
    Annun.getNode("gen-off").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gen-off").setBoolValue(0);
}

if(getprop("/systems/electrical/ac-volts") < 5){
    MstrWarn.setBoolValue(1 * PWR2);
    Annun.getNode("ac-fail").setBoolValue(1 * PWR2);
    Annun.getNode("invtr-fail").setBoolValue(1 * PWR2);
}else{
    Annun.getNode("ac-fail").setBoolValue(0);
    Annun.getNode("invtr-fail").setBoolValue(0);
        }

if(getprop("engines/engine[0]/rpm") < 40){
    Annun.getNode("fuel-psi").setBoolValue(1 * PWR2);
    Annun.getNode("hyd-flow").setBoolValue(1 * PWR2);
    Annun.getNode("hyd-psi").setBoolValue(1 * PWR2);
    Annun.getNode("stby-ps-htr").setBoolValue(1 * PWR2);
    Annun.getNode("aoa-htr").setBoolValue(1 * PWR2);
    Annun.getNode("ps-htr").setBoolValue(1 * PWR2);
}else{
        Annun.getNode("fuel-psi").setBoolValue(0);
        Annun.getNode("hyd-flow").setBoolValue(0);
        Annun.getNode("hyd-psi").setBoolValue(0);
        Annun.getNode("stby-ps-htr").setBoolValue(0);
        Annun.getNode("aoa-htr").setBoolValue(0);
        Annun.getNode("ps-htr").setBoolValue(0);
        }

if(getprop("engines/engine[1]/rpm") < 40){
    Annun.getNode("fuel-psi").setBoolValue(1 * PWR2);
    Annun.getNode("hyd-flow").setBoolValue(1 * PWR2);
    Annun.getNode("hyd-psi").setBoolValue(1 * PWR2);
}else{
        Annun.getNode("fuel-psi").setBoolValue(0);
        Annun.getNode("hyd-flow").setBoolValue(0);
        Annun.getNode("hyd-psi").setBoolValue(0);
        }


var spdbrk = getprop("/surface-positions/speedbrake-pos-norm");
if(spdbrk> 0.0){
    Annun.getNode("hyd-psi").setBoolValue(1 * PWR2);
    if(spdbrk == 1.0){
        Annun.getNode("spd-brk").setBoolValue(1 * PWR2);
        Annun.getNode("hyd-psi").setBoolValue(0);
    }
}else{
        Annun.getNode("hyd-psi").setBoolValue(0);
        Annun.getNode("spd-brk").setBoolValue(0);
        }

if(getprop("/controls/cabin-door/position-norm") != 0.0){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("cabin-door").setBoolValue(1 * PWR2);
    Annun.getNode("door-seal").setBoolValue(1 * PWR2);
    }else{
        Annun.getNode("cabin-door").setBoolValue(0);
        Annun.getNode("door-seal").setBoolValue(0);
        }
}

var Startup = func{
setprop("controls/electric/engine[0]/generator",1);
setprop("controls/electric/engine[1]/generator",1);
setprop("controls/electric/avionics-switch",1);
setprop("controls/electric/battery-switch",1);
setprop("controls/electric/inverter-switch",1);
setprop("controls/lighting/instrument-lights",1);
setprop("controls/lighting/nav-lights",1);
setprop("controls/lighting/beacon",1);
setprop("controls/lighting/strobe",1);
setprop("controls/engines/engine[0]/cutoff",0);
setprop("controls/engines/engine[1]/cutoff",0);
setprop("controls/engines/engine[0]/ignition",1);
setprop("controls/engines/engine[1]/ignition",1);
setprop("engines/engine[0]/running",1);
setprop("engines/engine[1]/running",1);
setprop("controls/engines/throttle_idle",1);
}

var Shutdown = func{
setprop("controls/electric/engine[0]/generator",0);
setprop("controls/electric/engine[1]/generator",0);
setprop("controls/electric/avionics-switch",0);
setprop("controls/electric/battery-switch",0);
setprop("controls/electric/inverter-switch",0);
setprop("controls/lighting/instrument-lights",1);
setprop("controls/lighting/nav-lights",0);
setprop("controls/lighting/beacon",0);
setprop("controls/lighting/strobe",0);
setprop("controls/engines/engine[0]/cutoff",1);
setprop("controls/engines/engine[1]/cutoff",1);
setprop("controls/engines/engine[0]/ignition",0);
setprop("controls/engines/engine[1]/ignition",0);
setprop("engines/engine[0]/running",0);
setprop("engines/engine[1]/running",0);
}

var dme_step = func(stp){
    var swtch= getprop("instrumentation/dme/switch-position");
    swtch += stp;
    if(swtch >3)swtch=3;
    if(swtch <0)swtch=0;
    setprop("instrumentation/dme/switch-position",swtch);

    if(swtch==0){
        setprop("instrumentation/dme/frequencies/source","instrumentation/dme/frequencies/selected-mhz");
    }elsif(swtch==1){
        setprop("instrumentation/dme/frequencies/source","instrumentation/nav[0]/frequencies/selected-mhz");
    }elsif(swtch==2){
        setprop("instrumentation/dme/frequencies/source","instrumentation/dme/frequencies/selected-mhz");
    }elsif(swtch==3){
        setprop("instrumentation/dme/frequencies/source","instrumentation/nav[1]/frequencies/selected-mhz");
    }
}

var set_radios = func(src,stp){
# Comm 118 - 136
# Nav 108-118
#ADF 100 - 1300
    var frq =0;
    if(src=="comm"){
        frq=getprop("instrumentation/comm/frequencies/standby-mhz");
        frq = frq+ stp;
        if(frq > 136.000)frq = frq-18.000;
        if(frq < 118.000)frq = frq+18.000;
        setprop("instrumentation/comm/frequencies/standby-mhz",frq);
    }elsif(src=="comm1"){
        frq=getprop("instrumentation/comm[1]/frequencies/standby-mhz");
        frq = frq+ stp;
        if(frq > 136.000)frq = frq-18.000;
        if(frq < 118.000)frq = frq+18.000;
        setprop("instrumentation/comm[1]/frequencies/standby-mhz",frq);
    }elsif(src=="nav"){
        frq=getprop("instrumentation/nav/frequencies/standby-mhz");
        frq = frq+ stp;
        if(frq > 118.000)frq = frq-10.000;
        if(frq < 108.000)frq = frq+10.000;
        setprop("instrumentation/nav/frequencies/standby-mhz",frq);
    }elsif(src=="nav1"){
        frq=getprop("instrumentation/nav[1]/frequencies/standby-mhz");
        frq = frq+ stp;
        if(frq > 118.000)frq = frq-10.000;
        if(frq < 108.000)frq = frq+10.000;
        setprop("instrumentation/nav[1]/frequencies/standby-mhz",frq);
    }elsif(src=="adf"){
        frq=getprop("instrumentation/adf/frequencies/standby-khz");
        frq = frq+ stp;
        if(frq > 1300)frq = frq-1200;
        if(frq < 100)frq = frq+1200;
        setprop("instrumentation/adf/frequencies/standby-khz",frq);
    }
}

var FHupdate = func(tenths){
        var fmeter = getprop("/instrumentation/clock/flight-meter-sec");
        var fhour = fmeter/3600;
        setprop("instrumentation/clock/flight-meter-hour",fhour);
        var fmin = fhour - int(fhour);
        if(tenths !=0){
            fmin *=100;
        }else{
            fmin *=60;
        }
        setprop("instrumentation/clock/flight-meter-min",int(fmin));
    }

########## MAIN ##############

var update_systems = func{
LHeng.update();
RHeng.update();

FHupdate(0);

        tire.get_rotation("yasim");

var gr1=getprop("gear/gear[0]/position-norm");
var gr2=getprop("gear/gear[1]/position-norm");
var gr3=getprop("gear/gear[2]/position-norm");
var GrWrn = 0;
var Ghorn = 0;
var GLock = 0;
    PWR2 =0;
    if(getprop("systems/electrical/bus-volts") > 2.0)PWR2=1;

if(gr1 != 1.0)GrWrn =1;
if(gr2 != 1.0)GrWrn =1;
if(gr3 != 1.0)GrWrn =1;

if(GrWrn ==1){
    if(getprop("engines/engine/n2")<70 or getprop("engines/engine[1]/n2")<70){
        if(getprop("velocities/airspeed-kt") < 150)Ghorn =1;
    }
    if(getprop("/surface-positions/flap-pos-norm") > 0.5)Ghorn =1;

if(gr1 != 0.0)GLock =1;
if(gr2 != 0.0)GLock =1;
if(gr3 != 0.0)GLock =1;
}

setprop("instrumentation/annunciators/gear-unlocked",GLock);
setprop("instrumentation/alerts/gear-horn",Ghorn);

annunciators_loop();
settimer(update_systems,0);
}
