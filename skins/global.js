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

// handler for allpath in json
var cnf_allpath = 'json.cgi?type=allpath';
var json_allpath = undefined;
var json_allpath_rev = {};
var json_allpath_order = []; // array of alphabetical sorted fullpath
function AcquireAllpath() {
  if (json_allpath != undefined) {return json_allpath; }
  json_allpath = GetData(cnf_allpath);
  if (json_allpath == undefined) {return undefined; }
  json_allpath = json_allpath.data;
  for (var i in json_allpath) {
    json_allpath_rev[json_allpath[i].fullpath] = json_allpath[i];
    json_allpath_order.push(json_allpath[i].fullpath);
  }
  json_allpath_order.sort(function(a,b) {
    if (a < b) {return -1; }; if (a > b) {return 1; }; return 0;
  });
  return json_allpath;
}

function SetPathSelect(sel_id, cur_id) {
  if (sel_id == '') {return ; }
  AcquireAllpath();
  var sel = document.getElementById(sel_id);
  if (sel.length > 0) {return; }
  var co = document.createElement('option');
  co.text = "/";
  co.value = 0;
  sel.options.add(co);
  for (var i = 0; i < json_allpath_order.length; i++) {
    co = document.createElement('option');
    co.text = json_allpath_order[i];
    co.value = json_allpath_rev[json_allpath_order[i]].pathid;
    if (co.value == cur_id) {co.selected = true; }
    sel.options.add(co);
  }
}

