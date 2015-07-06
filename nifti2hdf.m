% Uncomment to test with NIFTI-1:
niiname = 'MNI152_T1_2mm_brain.nii';
hdfname = 'MNI152_T1_2mm_brain.h5';

% Uncomment to test with NIFTI-2:
% niiname = 'MNI152_T1_1mm_nifti2.nii';
% hdfname = 'MNI152_T1_1mm_nifti2.h5';

% Read the NIFTI file
% ------------------------------------------------------------------
nii = niihdrread(niiname);

% Create the HDF5 file:
% ------------------------------------------------------------------
% To create a file, we need to define what to do if it already
% exists. A property object is created to define the behaviour.
% For H5F.create, the possibilities are:
% - H5F_ACC_EXCL:  Fails creation if the file already exists.
% - H5F_ACC_TRUNC: Creates a new file, overwriting the existing one.
% The default is H5F_ACC_EXCL, but we'll use H5F_ACC_TRUNC.
% Regarding creation and access property lists, we will leave now
% the defaults but later consider specifics for higher performance.
file_id = H5F.create(hdfname, 'H5F_ACC_TRUNC', ...
    'H5P_DEFAULT', 'H5P_DEFAULT');

% Create the group to store volume-based data:
% ------------------------------------------------------------------
% Default property lists, kept as default for now.
% The group is being opened now, but it will be closed later.
group_id = H5G.create(file_id, '/volume', ...
    'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

% Define the datatype for the volume:
% ------------------------------------------------------------------
% The library allows for IEEE754 types, as well as for types in
% architectures (Intel, Cray, MIPS, Alpha, etc), and both endiannesses.
% However, to ensure compatibility for any user, anywhere, we'll use
% NATIVE, which corresponds to the format of the machine in which the
% file will be used.
switch nii.hdr.datatype,
    case    1, dtype_id = H5T.copy('H5T_NATIVE_HBOOL'  ); % Bool
    case    2, dtype_id = H5T.copy('H5T_NATIVE_UINT8'  ); % Unsigned char
    case    4, dtype_id = H5T.copy('H5T_NATIVE_SHORT'  ); % Signed short
    case    8, dtype_id = H5T.copy('H5T_NATIVE_INT'    ); % Signed int
    case   16, dtype_id = H5T.copy('H5T_NATIVE_FLOAT'  ); % Float
    case   32, dtype_id = H5T.copy('H5T_NATIVE_B32'    ); % Complex
    case   64, dtype_id = H5T.copy('H5T_NATIVE_DOUBLE' ); % Double
    case  256, dtype_id = H5T.copy('H5T_NATIVE_INT8'   ); % Signed char
    case  512, dtype_id = H5T.copy('H5T_NATIVE_USHORT' ); % Unsigned short
    case  768, dtype_id = H5T.copy('H5T_NATIVE_UINT'   ); % Unsigned int
    case 1024, dtype_id = H5T.copy('H5T_NATIVE_LLONG'  ); % Long long
    case 1280, dtype_id = H5T.copy('H5T_NATIVE_ULLONG' ); % Unsigned long long
    case 1536, dtype_id = H5T.copy('H5T_NATIVE_LDOUBLE'); % Long double
    case 1792, dtype_id = H5T.copy('H5T_NATIVE_B64'    ); % Double pair
    case 2304, dtype_id = H5T.copy('H5T_NATIVE_B32'    ); % RGBA
    otherwise
        error('Datatype %d not supported.', nii.hdr.datatype);
end

% Define the dataspace for the volume:
% ------------------------------------------------------------------
% For multi-dimensional arrays, the dataspace is of the type 'SIMPLE'.
% Note that the extent of each of the dimensions needs "fliplr" due to
% C/FORTRAN differences. It also needs to be "double".
% The dataspace is being opened now, but it will be closed later.
dspace_id = H5S.create('H5S_SIMPLE');
ndim      = double(nii.hdr.dim(1));
dims      = double(fliplr(nii.hdr.dim(2:ndim+1)));
H5S.set_extent_simple(dspace_id, ndim, dims, dims);

% Define and write the dataset, i.e., the actual volume:
% ------------------------------------------------------------------
% Creates an empty dataset, using the datatype and dataspace defined
% above. Then write the contents of the NIFTI to it. Like everything
% else, each needs to be closed. The dataset proper, however, will
% remain open for now to allow adding attributes.
dset_id = H5D.create(file_id, '/volume/data', dtype_id, dspace_id, ...
    'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
H5T.close(dtype_id);
H5S.close(dspace_id);
H5D.write(dset_id, 'H5ML_DEFAULT','H5S_ALL', ...
    'H5S_ALL','H5P_DEFAULT', nii.img);

% Define the dataset attributes:
% ------------------------------------------------------------------
% These are the pieces of information from the NIFTI header.

if nii.hdr.niftiversion == 1,
    
    % NIFTI-1:
    % --------------------------------------------------------------
    % [sizeof_hdr]:     Removed field.
    % [data_type]:      Removed field.
    % [db_name]:        Removed field.
    % [extents]:        Removed field.
    % [session_error]:  Removed field.
    % [regular]:        Removed field.
    
    % [dim_info]:       Needs splitting into three fields.
    dim_info    = de2bi(nii.hdr.dim_info,8);
    
    %  freq_dim:        New field, from dim_info.
    freq_dim  = int8(bi2de(dim_info(1:2)));
    atype_id  = H5T.copy('H5T_NATIVE_INT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'freq_dim', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', freq_dim);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    %  phase_dim:       New field, from dim_info.
    phase_dim = int8(bi2de(dim_info(3:4)));
    atype_id  = H5T.copy('H5T_NATIVE_INT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'phase_dim', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', phase_dim);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    %  slice_dim:       New field, from dim_info.
    slice_dim = int8(bi2de(dim_info(3:4)));
    atype_id  = H5T.copy('H5T_NATIVE_INT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_dim', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', slice_dim);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [dim]:            Removed field.
    
    % [intent_p1]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent_p1', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_p1);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [intent_p2]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent_p2', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_p2);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [intent_p3]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent_p3', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_p3);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [intent_code]:    Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_SHORT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_code);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [data_type]:      Removed field.
    % [bitpix]:         Removed field.
    
    % [slice_start]:    Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_SHORT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_start', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.slice_start);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [pixdim]:         Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SIMPLE');
    H5S.set_extent_simple(aspace_id, 1, ndim, ndim);
    attr_id   = H5A.create(dset_id, 'pixdim', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.pixdim(2:ndim+1));
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [vox_offset]:     Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_INT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'vox_offset', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', int32(nii.hdr.vox_offset));
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [scl_slope]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'scl_slope', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.scl_slope);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [scl_inter]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'scl_inter', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.scl_inter);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [slice_end]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_SHORT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_end', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.slice_end);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [slice_code]:     Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_INT8');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_code', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.slice_code);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [xyzt_units]:     Needs splitting into two fields.
    xyzt_units = de2bi(nii.hdr.xyzt_units,8);
    
    %  spatial_units:   New field, from xyzt_units.
    spatial_units  = int8(bi2de(xyzt_units & de2bi(hex2dec('07'),8)));
    atype_id       = H5T.copy('H5T_NATIVE_INT8');
    aspace_id      = H5S.create('H5S_SCALAR');
    attr_id        = H5A.create(dset_id, 'spatial_units', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', spatial_units);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    %  temporal_units:  New field, from xyzt_units.
    temporal_units = int8(bi2de(xyzt_units & de2bi(hex2dec('38'),8)));
    atype_id       = H5T.copy('H5T_NATIVE_INT8');
    aspace_id      = H5S.create('H5S_SCALAR');
    attr_id        = H5A.create(dset_id, 'temporal_units', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', temporal_units);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [cal_min]:        Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'cal_min', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.cal_min);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [cal_max]:        Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'cal_max', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.cal_max);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [slice_duration]: Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_duration', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.slice_duration);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [toffset]:        Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'toffset', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.toffset);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [glmax]:          Removed field.
    % [glmin]:          Removed field.

    % [descrip]:        Preserved field.
    atype_id  = H5T.copy('H5T_C_S1');
    H5T.set_size(atype_id,80);
    H5T.set_strpad(atype_id,'H5T_STR_NULLTERM');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'descrip', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.descrip);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [aux_file]:       Preserved field (consider deprecation).
    atype_id  = H5T.copy('H5T_C_S1');
    H5T.set_size(atype_id,24);
    H5T.set_strpad(atype_id,'H5T_STR_NULLTERM');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'aux_file', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.aux_file);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [qform_code]:     Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_SHORT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'qform_code', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.qform_code);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [sform_code]:     Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_SHORT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'sform_code', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.sform_code);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [quatern_*]:      Modified field to full affine.
    % [qoffset_*]:      Modified field to full affine.
    affine_q = quaternion2affine(...
        [nii.hdr.quatern_b nii.hdr.quatern_c nii.hdr.quatern_d], ...
        nii.hdr.pixdim(1:4), ...
        [nii.hdr.qoffset_x nii.hdr.qoffset_y nii.hdr.qoffset_z]);
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SIMPLE');
    H5S.set_extent_simple(aspace_id, 2, [4 4], [4 4]);
    attr_id   = H5A.create(dset_id, 'affine_q', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', single(affine_q'));
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [srow_*]:         Modified field to full affine.
    affine_s = [ ...
        nii.hdr.srow_x; ...
        nii.hdr.srow_y; ...
        nii.hdr.srow_z; ...
        0 0 0 1];
    atype_id  = H5T.copy('H5T_NATIVE_FLOAT');
    aspace_id = H5S.create('H5S_SIMPLE');
    H5S.set_extent_simple(aspace_id, 2, [4 4], [4 4]);
    attr_id   = H5A.create(dset_id, 'affine_s', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', single(affine_s'));
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [intent_name]:    Preserved field.
    atype_id  = H5T.copy('H5T_C_S1');
    H5T.set_size(atype_id,16);
    H5T.set_strpad(atype_id,'H5T_STR_NULLTERM');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent_name', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_name);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [magic]:          Removed field.
    % [extension]:      Removed field.
    
elseif nii.hdr.niftiversion == 2,
    
    % NIFTI-2:
    % --------------------------------------------------------------
    % [sizeof_hdr]:     Removed field.
    % [magic]:          Removed field.
    % [data_type]:      Removed field.
    % [bitpix]:         Removed field.
    % [dim]:            Removed field.
    
    % [intent_p1]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent_p1', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_p1);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [intent_p2]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent_p2', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_p2);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [intent_p3]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent_p3', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_p3);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [pixdim]:         Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SIMPLE');
    H5S.set_extent_simple(aspace_id, 1, ndim, ndim);
    attr_id   = H5A.create(dset_id, 'pixdim', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.pixdim(2:ndim+1));
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [vox_offset]:     Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_INT64');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'vox_offset', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.vox_offset);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [scl_slope]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'scl_slope', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.scl_slope);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [scl_inter]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'scl_inter', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.scl_inter);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [cal_min]:        Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'cal_min', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.cal_min);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [cal_max]:        Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'cal_max', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.cal_max);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [slice_duration]: Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_duration', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.slice_duration);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [toffset]:        Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'toffset', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.toffset);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [slice_start]:    Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_start', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.slice_start);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [slice_end]:      Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_end', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.slice_end);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [descrip]:        Preserved field.
    atype_id  = H5T.copy('H5T_C_S1');
    H5T.set_size(atype_id,80);
    H5T.set_strpad(atype_id,'H5T_STR_NULLTERM');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'descrip', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.descrip);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [aux_file]:       Preserved field (consider deprecation).
    atype_id  = H5T.copy('H5T_C_S1');
    H5T.set_size(atype_id,24);
    H5T.set_strpad(atype_id,'H5T_STR_NULLTERM');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'aux_file', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.aux_file);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [qform_code]:     Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_INT32');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'qform_code', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.qform_code);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [sform_code]:     Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_INT32');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'sform_code', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.sform_code);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [quatern_*]:      Modified field to full affine.
    % [qoffset_*]:      Modified field to full affine.
    affine_q = quaternion2affine(...
        [nii.hdr.quatern_b nii.hdr.quatern_c nii.hdr.quatern_d], ...
        nii.hdr.pixdim(1:4), ...
        [nii.hdr.qoffset_x nii.hdr.qoffset_y nii.hdr.qoffset_z]);
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SIMPLE');
    H5S.set_extent_simple(aspace_id, 2, [4 4], [4 4]);
    attr_id   = H5A.create(dset_id, 'affine_q', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', affine_q');
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [srow_*]:         Modified field to full affine.
    affine_s = [ ...
        nii.hdr.srow_x; ...
        nii.hdr.srow_y; ...
        nii.hdr.srow_z; ...
        0 0 0 1];
    atype_id  = H5T.copy('H5T_NATIVE_DOUBLE');
    aspace_id = H5S.create('H5S_SIMPLE');
    H5S.set_extent_simple(aspace_id, 2, [4 4], [4 4]);
    attr_id   = H5A.create(dset_id, 'affine_s', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', affine_s');
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [slice_code]:     Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_INT32');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_code', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.slice_code);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [xyzt_units]:     Needs splitting into four fields.
    xyzt_units = de2bi(nii.hdr.xyzt_units,32);
    
    %  x_units:         New field, from xyzt_units.
    x_units        = int8(bi2de(xyzt_units(1:8)));
    atype_id       = H5T.copy('H5T_NATIVE_INT8');
    aspace_id      = H5S.create('H5S_SCALAR');
    attr_id        = H5A.create(dset_id, 'x_units', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', x_units);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    %  y_units:         New field, from xyzt_units.
    y_units        = int8(bi2de(xyzt_units(9:16)));
    atype_id       = H5T.copy('H5T_NATIVE_INT8');
    aspace_id      = H5S.create('H5S_SCALAR');
    attr_id        = H5A.create(dset_id, 'y_units', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', y_units);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    %  z_units:         New field, from xyzt_units.
    z_units        = int8(bi2de(xyzt_units(17:24)));
    atype_id       = H5T.copy('H5T_NATIVE_INT8');
    aspace_id      = H5S.create('H5S_SCALAR');
    attr_id        = H5A.create(dset_id, 'z_units', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', z_units);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    %  t_units:         New field, from xyzt_units.
    t_units        = int8(bi2de(xyzt_units(25:32)));
    atype_id       = H5T.copy('H5T_NATIVE_INT8');
    aspace_id      = H5S.create('H5S_SCALAR');
    attr_id        = H5A.create(dset_id, 't_units', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', t_units);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [intent_code]:    Preserved field.
    atype_id  = H5T.copy('H5T_NATIVE_INT32');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_code);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [intent_name]:    Preserved field.
    atype_id  = H5T.copy('H5T_C_S1');
    H5T.set_size(atype_id,16);
    H5T.set_strpad(atype_id,'H5T_STR_NULLTERM');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'intent_name', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', nii.hdr.intent_name);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [dim_info]:       Needs splitting into three fields.
    dim_info    = de2bi(nii.hdr.dim_info,8);
    
    %  freq_dim:        New field, from dim_info.
    freq_dim  = int8(bi2de(dim_info(1:2)));
    atype_id  = H5T.copy('H5T_NATIVE_INT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'freq_dim', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', freq_dim);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    %  phase_dim:       New field, from dim_info.
    phase_dim = int8(bi2de(dim_info(3:4)));
    atype_id  = H5T.copy('H5T_NATIVE_INT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'phase_dim', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', phase_dim);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    %  slice_dim:       New field, from dim_info.
    slice_dim = int8(bi2de(dim_info(3:4)));
    atype_id  = H5T.copy('H5T_NATIVE_INT');
    aspace_id = H5S.create('H5S_SCALAR');
    attr_id   = H5A.create(dset_id, 'slice_dim', atype_id, ...
        aspace_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, 'H5ML_DEFAULT', slice_dim);
    H5A.close(attr_id); H5S.close(aspace_id); H5T.close(atype_id);
    
    % [unused_str]:     Removed field.
    % [extension]:      Removed field.
end

% Close the dataset, group, and the file:
% ------------------------------------------------------------------
H5D.close(dset_id);
H5G.close(group_id);
H5F.close(file_id);