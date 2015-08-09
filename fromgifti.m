function fromnifti(varargin)
% Convert a GIFTI file to a basic HDF5.
% Currently there is no chunking or compression.
%
% Usage:
% fromgifti(giiname, hdfname)
%
% - giiname: Filename of the GIFTI file.
% - hdfname: Finename of the output HDF5 file. If omitted, the
%            default name is the same as the GIFTI, but with
%            extension .h5.
% 
% _____________________________________
% Anderson M. Winkler
% FMRIB / Univ. of Oxford
% Jul/2015
% http://brainder.org

% Parse inputs
narginchk(1,2);
giiname = varargin{1};
if nargin == 1 || isempty(varargin{2}),
    [fpth, fnam, fext] = fileparts(giiname);
    hdfname = fullfile(fpth, horzcat(fnam,'.h5'));
else
    hdfname = varargin{2};
end

% Define subject index and volume index, such that the data
% will be stored in: /id%d/vol%d
id_idx   = 1;

% Read the GIFTI file
% ------------------------------------------------------------------
hdf = giftiread(giiname);

% Create the HDF5 file:
% ------------------------------------------------------------------
% We can certainly append an existing file. For the time being, let's
% create a new one from scratch. We will fix this in the near future.
file_id = H5F.create(hdfname, 'H5F_ACC_TRUNC', ...
    'H5P_DEFAULT', 'H5P_DEFAULT');

% % Create the group to store data for this subject:
% % ------------------------------------------------------------------
% % Default property lists, kept as default for now.
% id_id = H5G.create(file_id, sprintf('id%d', id_idx), ...
%     'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

% Loop over each dataarray in the HDF file:
% ------------------------------------------------------------------
for da = 1:numel(hdf),
    
%     % Create the appropriate group if it doesn't exist.
%     % --------------------------------------------------------------
%     if ~ H5L.exists(id_id, hdf{da}.dset_name, 'H5P_DEFAULT'),
%         grp_id   = H5G.create(id_id, hdf{da}.dset_name, ...
%             'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
%         dset_idx = 1;
%     else
%         grp_id   = H5G.open(id_id, hdf{da}.dset_name ,'H5P_DEFAULT');
%         info     = H5G.get_info(grp_id);
%         dset_idx = info.nlinks + 1;
%     end
%     H5G.close(grp_id);
    
    % Define the dataspace:
    % --------------------------------------------------------------
    dspace_id = H5S.create('H5S_SIMPLE');
    dims      = size(hdf{da}.data);
    ndim      = numel(dims);
    H5S.set_extent_simple(dspace_id, ndim, dims, dims);
    
    % Define the datatype:
    % --------------------------------------------------------------
    dtype_id = H5T.copy(hdf{da}.attr.datatype);
    
    % Define and write the dataset, i.e., the actual volume:
    % --------------------------------------------------------------
    % Creates an empty dataset, using the datatype and dataspace defined
    % above. Then write the data contents to it. Like everything else,
    % each needs to be closed. The dataset proper, however, will
    % remain open for now to allow adding attributes.
    % Currently, there is a risk that with weird GIFTI files can have
    % multiple dataarrays with the same name without representing time
    % series. This will need addressing soon.
    dset_id = H5D.create(file_id, hdf{da}.dset_name, ...
        dtype_id, dspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5T.close(dtype_id);
    H5S.close(dspace_id);
    H5D.write(dset_id, 'H5ML_DEFAULT','H5S_ALL', ...
        'H5S_ALL','H5P_DEFAULT', permute(hdf{da}.data,ndim:-1:1));
    
    % Define the dataset attributes:
    % --------------------------------------------------------------
    % Most of this information are either software-specific or even
    % potentially harmful (e.g., subject name). It's included below for
    % compatibility but we should probably make an effort to ditch nearly
    % all these fields. Let's begin with those that are likely to be
    % useful:
    F = fields(hdf{da}.attr);
    for f = 1:numel(F),
        if strcmp(F{f},'datatype'),
            
            % do nothing for the attribute "datatype" (implicitly taken
            % care of above).
            
        elseif strcmp(F{f},'affine'),
            
            % Affine matrix (for points)
            atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
            aspace_id = H5S.create('H5S_SIMPLE');
            H5S.set_extent_simple(aspace_id, 2, [4 4], [4 4]);
            attr_id   = H5A.create(dset_id, 'affine', atype_id, ...
                aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
            H5A.write(attr_id, 'H5ML_DEFAULT', single(hdf{da}.attr.(F{f}))');
            H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
            
        elseif strcmp(F{f},'index'),
            
            % Label indices stored as attributes
            for lab = 1:size(hdf{da}.attr.index,1),
                atype_id  = H5T.copy('H5T_C_S1');
                H5T.set_size(atype_id,numel(hdf{da}.attr.index{lab,2}));
                H5T.set_strpad(atype_id,'H5T_STR_NULLTERM');
                aspace_id = H5S.create('H5S_SCALAR');
                attr_id   = H5A.create(dset_id, ...
                    num2str(hdf{da}.attr.index{lab,1}), atype_id, ...
                    aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
                H5A.write(attr_id, 'H5ML_DEFAULT', hdf{da}.attr.index{lab,2});
                H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
            end
            
        elseif ischar(hdf{da}.attr.(F{f})) && numel(hdf{da}.attr.(F{f})) > 0,
            
            % Everything else
            atype_id  = H5T.copy('H5T_C_S1');
            H5T.set_size(atype_id,numel(hdf{da}.attr.(F{f})));
            H5T.set_strpad(atype_id,'H5T_STR_NULLTERM');
            aspace_id = H5S.create('H5S_SCALAR');
            attr_id   = H5A.create(dset_id, F{f}, atype_id, ...
                aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
            H5A.write(attr_id, 'H5ML_DEFAULT', hdf{da}.attr.(F{f}));
            H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
        end
    end
end

% Close the dataset and the file:
% ------------------------------------------------------------------
H5D.close(dset_id);
% H5G.close(id_id);
H5F.close(file_id);