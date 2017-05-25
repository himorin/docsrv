// general toggle class

function tweak_ToggleClass (target, css) {
  var elem = $("." + target);
  for (var i = 0; i < elem.length; i++) {
    if ($(elem[i]).hasClass(css)) {$(elem[i]).removeClass(css); }
    else {$(elem[i]).addClass(css); }
  }
}

// favorite

var fav_callback_success = function(data) {
  if (data.fav == undefined) {
    alert("Exec failed: " + data.error.message);
    return;
  }
  var elem, target_id;
  if (data.fav.did == undefined) {
    if (data.fav.pid == undefined) {
      alert("Invalid operation: no target");
      return;
    }
    // path
    elem = $("#fav_p" + data.fav.pid)[0];
    target_id = data.fav.pid;
  } else {
    elem = $("#fav_" + data.fav.did)[0];
    target_id = data.fav.did;
  }
  if (elem == undefined) {alert("No such id " + target_id); }
  else if (data.fav.op == 'add') {
    $(elem).addClass('fav_on');
    elem.src = 'skins/images/default/woofunction_16_star.png';
  } else if (data.fav.op == 'remove') {
    $(elem).removeClass('fav_on');
    elem.src = 'skins/images/default/woofunction_16_star_off.png';
  } else {alert('Invalid operation: ' + target_id + ' / ' + data.fav.op);}
}

function tweak_ToggleFav (target) {
  var elem = $("#fav_" + target)[0];
  if (!(elem != undefined)) {return ; }
  var url = 'docfav.cgi?format=json&did=' + target + '&op=';
  if ($(elem).hasClass('fav_on')) {url += 'remove'; }
  else {url += 'add'; }
  $.ajax({type: 'GET', url: url, dataType: 'json'}).done(fav_callback_success
    ).fail(function(data, stat, errorTh){alert("Async call failed: " + stat);});
}

function tweak_ToggleFavPath (target) {
  var elem = $("#fav_p" + target)[0];
  if (!(elem != undefined)) {return ; }
  var url = 'docfav.cgi?format=json&pid=' + target + '&op=';
  if ($(elem).hasClass('fav_on')) {url += 'remove'; }
  else {url += 'add'; }
  $.ajax({type: 'GET', url: url, dataType: 'json'}).done(fav_callback_success
    ).fail(function(data, stat, errorTh){alert("Async call failed: " + stat);});
}

function AllPathChange() {
/*
  var selid = document.docadd_set.pid.selectedIndex;
  var hid = document.docadd_set.pid.options[selid].value;
  if (hid == 0) {
    document.getElementById("hid").innerHTML = 0;
    document.getElementById("fullpath").innerHTML = "";
    document.getElementById("desc").innerHTML = "Top Directory";
  } else {
    document.getElementById("hid").innerHTML = hid;
    document.getElementById("fullpath").innerHTML = conf_data_allpath.data[hid].fullpath;
    document.getElementById("desc").innerHTML = conf_data_allpath.data[hid].description;
  }
*/
}


// InfoTip will use id 'gbit' element

var def_gbit_id = 'gbit';

function show_infotip_path(target) {
    document.getElementById(def_gbit_id).style.display = 'block';
}

function show_infotip_doc(target) {
    document.getElementById(def_gbit_id).style.display = 'block';
}

function hide_infotip() {
    document.getElementById(def_gbit_id).style.display = 'none';
}

// admin flag
function set_admin(target) {
    if (target == 'enable') {$.cookie('admin', 'enable', {expires: 28}); }
    else {$.cookie('admin', 'disable', {expires: 28}); }
    location.reload();
}

// helper function for GET query
function GetData(url) {
  var httpReq = new XMLHttpRequest();
  var json_data;
  httpReq.open('GET', url, false);
  httpReq.send();
  if (httpReq.status === 200) {
    json_data = JSON.parse(httpReq.responseText);
  } else {
      return undefined;
  } 
  return json_data;
}

