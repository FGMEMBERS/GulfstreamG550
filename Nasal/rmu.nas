#Radio Management Unit 
# ie: var RMU1 = RMU.new(unit,com number.nav number);
var RMU = {
    new : func(unit,com,nav){
        m = { parents : [RMU]};
        var prp = props.globals.getNode("instrumentation/rmu",1);
        m.RMU=prp.getNode("unit["~unit~"]",1);
        m.com_num=m.RMU.getNode("com-num",1);
        m.com_num.setIntValue(com);
        m.nav_num=m.RMU.getNode("nav-num",1);
        m.nav_num.setIntValue(nav);
        m.adf_num=m.RMU.getNode("adf-num",1);
        m.adf_num.setIntValue(0);
        m.selected=m.RMU.getNode("selected",1);
        m.selected.setValue("com");
        m.selected_x=m.RMU.getNode("selected-xoffset",1);
        m.selected_x.setDoubleValue(0);
        m.selected_y=m.RMU.getNode("selected-yoffset",1);
        m.selected_y.setDoubleValue(0);
        m.com_freq=m.RMU.getNode("com-freq",1);
        m.com_freq.setDoubleValue(999.99);
        m.com_stby=m.RMU.getNode("com-stby",1);
        m.com_stby.setDoubleValue(999.99);
        m.nav_freq=m.RMU.getNode("nav-freq",1);
        m.nav_freq.setDoubleValue(999.99);
        m.nav_stby=m.RMU.getNode("nav-stby",1);
        m.nav_stby.setDoubleValue(999.99);
        m.adf_freq=m.RMU.getNode("adf-freq",1);
        m.adf_freq.setDoubleValue(379.0);
        m.atc_freq=m.RMU.getNode("atc-freq",1);
        m.atc_freq.setDoubleValue(1200);
    return m;
    },
#### selector ####
    button : func(act){
        if(act=="com-swp"){
            var frq = me.com_freq.getValue();
            me.com_freq.setValue(me.com_stby.getValue());
            me.com_stby.setValue(frq);
        }elsif(act=="nav-swp"){
            var nfrq = me.nav_freq.getValue();
            me.nav_freq.setValue(me.nav_stby.getValue());
            me.nav_stby.setValue(nfrq);
        }elsif(act=="slct-com"){
            me.selected.setValue("com");
            me.selected_x.setValue(0);
            me.selected_y.setValue(0);
        }elsif(act=="slct-nav"){
            me.selected.setValue("nav");
            me.selected_x.setValue(1);
            me.selected_y.setValue(0);
        }elsif(act=="slct-atc"){
            me.selected.setValue("atc");
            me.selected_x.setValue(0);
            me.selected_y.setValue(1);
        }elsif(act=="slct-adf"){
            me.selected.setValue("adf");
            me.selected_x.setValue(1);
            me.selected_y.setValue(1);
        }
    },
#### copy frequencies to radios ####
    update : func(){
        var num = me.com_num.getValue();
        setprop("instrumentation/comm["~num~"]/frequencies/selected-mhz",me.com_freq.getValue());
        setprop("instrumentation/comm["~num~"]/frequencies/standby-mhz",me.com_stby.getValue());
        num = me.nav_num.getValue();
        setprop("instrumentation/nav["~num~"]/frequencies/selected-mhz",me.nav_freq.getValue());
        setprop("instrumentation/nav["~num~"]/frequencies/standby-mhz",me.nav_stby.getValue());
        setprop("instrumentation/adf/frequencies/selected-khz",me.adf_freq.getValue());
        setprop("instrumentation/kt-70/outputs/id-code",me.atc_freq.getValue());
    },
#### tune frequencies ####
    tune : func(amt,btn){
        var slc = me.selected.getValue();
        var val = 0;
        var frq =0;
        if(slc=="com"){
            frq=me.com_stby.getValue();
            if(btn ==0){
                val=0.025 * amt;
            }else{
                val=1.000 * amt;
            }
            frq +=val;
            if(frq>136.000)frq-=18.000;
            if(frq<118.000)frq+=18.000;
            me.com_stby.setValue(frq);
        }elsif(slc=="nav"){
            frq=me.nav_stby.getValue();
            if(btn ==0){
                val=0.050 * amt;
            }else{
                val=1.000 * amt;
            }
            frq +=val;
            if(frq>118.000)frq-=10.000;
            if(frq<108.000)frq+=10.000;
            me.nav_stby.setValue(frq);
        }elsif(slc=="atc"){
            frq=me.atc_freq.getValue();
            if(btn ==0){
                val=1 * amt;
            }else{
                val=100 * amt;
            }
            frq +=val;
            if(frq>5555.0)frq-=5555.0;
            if(frq<0.0)frq+=5555.0;
            me.atc_freq.setValue(frq);
        }elsif(slc=="adf"){
            frq=me.adf_freq.getValue();
            if(btn ==0){
                val=1.0 * amt;
            }else{
                val=100.0 * amt;
            }
            frq +=val;
            if(frq>1800.0)frq-=1610.0;
            if(frq<190.0)frq+=1610.0;
            me.adf_freq.setValue(frq);
        }
    },

};

##############################
##############################

var RMU1 = RMU.new(0,0,0);
var RMU2 = RMU.new(1,1,1);

setlistener("/sim/signals/fdm-initialized", func {
init_rmu();
});

setlistener("/sim/signals/reinit", func {
init_rmu();
});

var init_rmu=func(){
    RMU1.com_freq.setValue(120.500);
    RMU1.com_stby.setValue(118.850);
    RMU1.nav_freq.setValue(115.80);
    RMU1.nav_stby.setValue(111.70);

    RMU2.com_freq.setValue(118.300);
    RMU2.com_stby.setValue(133.775);
    RMU2.nav_freq.setValue(116.80);
    RMU2.nav_stby.setValue(113.90);
}

######## unit 1 ############
setlistener(RMU1.com_freq, func(){
    RMU1.update();
},1,0);

setlistener(RMU1.com_stby, func(){
    RMU1.update();
},1,0);

setlistener(RMU1.nav_freq, func(){
    RMU1.update();
},1,0);

setlistener(RMU1.nav_stby, func(){
    RMU1.update();
},1,0);

setlistener(RMU1.adf_freq, func(){
    RMU1.update();
},1,0);

setlistener(RMU1.atc_freq, func(){
    RMU1.update();
},1,0);

######## unit 2 ############

setlistener(RMU2.com_freq, func(){
    RMU2.update();
},1,0);

setlistener(RMU2.com_stby, func(){
    RMU2.update();
},1,0);

setlistener(RMU2.nav_freq, func(){
    RMU2.update();
},1,0);

setlistener(RMU2.nav_stby, func(){
    RMU2.update();
},1,0);

setlistener(RMU2.adf_freq, func(){
    RMU2.update();
},1,0);

setlistener(RMU2.atc_freq, func(){
    RMU2.update();
},1,0);
