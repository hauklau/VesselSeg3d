function err =  te_oneImg(varargin)
%te_oneImg test on one image pixelwise, save the prediction scores as mha
% te_oneImg(); as script
% te_oneImg(fn_mo, dir_name, h_get_x, h_get_y, dir_out_s); as function

if (nargin==0) % config (as script)
  
  dir_mo = 'D:\CodeWork\git\VesselSeg3d\mo_zoo';
  name_mo = 'net3d6_nh16';
  cnt_mo = 'ep_1141';
  fn_mo = fullfile(dir_mo, name_mo, [cnt_mo,'.mat']);
  % handles
  hgetx = @get_x_cubic24;
  hgety = @get_y_cen1;
  
  % 
  batch_sz = 256;
  % testing image (instances), ground truth(labels)
  name     = '01-001-MAP';
  dir_name = fullfile('D:\data\defactoSeg2\', name);
  fn_mha   = fullfile(dir_name, 't.mha');          % the CT volume
  fn_fgbg  = fullfile(dir_name, 'maskfgbg.mha');   % the fg bg mask

  % output file name
  dir_out_s = fullfile('.\', name_mo, cnt_mo);
  if (~exist(dir_out_s,'dir')), mkdir(dir_out_s); end 
  fn_out_s  = fullfile(dir_out_s, [name,'_pre_s.mha']);
else % TODO: need fixing
  batch_sz = 1024;
  fn_mo = varargin{1};
  % instances, labels...
  dir_name = varargin{2};
  fn_mha   = fullfile(dir_name, 't.mha');          % the CT volume
  fn_fgbg  = fullfile(dir_name, 'maskfgbg.mha');   % the fg bg mask
  % handles
  hgetx = varargin{3};
  hgety = varargin{4};
  % output file name
  [~,name] = fileparts(dir_name);
  dir_out_s = varargin{5}; 
  fn_out_s  = fullfile(dir_out_s, [name,'_pre_s.mha']);
end

% load data 
function te_bdg = load_te_data()
  mha     = mha_read_volume(fn_mha);
  mk_fgbg = mha_read_volume(fn_fgbg);
  te_bdg  = bdg_mhaSampLazy(mha, mk_fgbg, batch_sz, hgetx, hgety);
end
fprintf('loading volume %s...', fn_mha);
te_bdg = load_te_data();
fprintf('data\n');

% load model
fprintf('loading model %s...', fn_mo);
st = load(fn_mo);
ob = st.ob;
clear st;
fprintf('done\n');

% statistics
fprintf('# mask pixels = %d\n', numel(te_bdg.ix_fgbg) );
fprintf('# foreground mask pixels = %d\n', numel(te_bdg.ix_fg) );
fprintf('# background mask pixels = %d\n', numel(te_bdg.ix_bg) );
  
% do the job: testing it
Ypre = test(ob, te_bdg);
Ypre = gather(Ypre);

% show the error
Ygt = get_all_Ygt(te_bdg);
[err, err_one, err_two] = get_bin_cls_err(Ypre, Ygt);
fprintf('classification error = %0.3f\n', err );
fprintf('background misclassfication rate = %0.3f\n', err_one );
fprintf('foreground misclassfication rate = %0.3f\n', err_two );

% restore prediction to vesselness scores and write
out_s = get_pre_score(Ypre, te_bdg);
mhawrite(fn_out_s, out_s);

end % te_oneImg

function out = get_pre_score(Ypre, te_bdg)
  out = zeros(size(te_bdg.mk_fgbg), 'single');
  
  K = size(Ypre,1);
  if (K==1)
    s = Ypre;
  else
    s = Ypre(2,:) - Ypre(1,:);
  end
  out( te_bdg.ix_fgbg ) = single( s(:) );
end