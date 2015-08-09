function hdf = giftiread(giifile)
% Read a GIFTI file and returns an intermediate struct that can be used
% to generate the HDF5 file.
%
% hdf = giftiread(filename)
%
% - filename   : File to be read.
% - hdf        : Struct with the content of the file, already arranged
%                to facilitate writing as HDF5.
%
% Currently node, vector, and tensor data are not supported (lack of
% example files, and the standard isn't clear how these should be
% stored in the data array).
%
% _____________________________________
% Anderson M. Winkler
% FMRIB / Univ. of Oxford
% Jul/2015
% http://brainder.org

% For speed, allow also input as a GIFTI object
if isa(giifile,'gifti'),
    gii = giifile.private;
else
    gii = gifti(giifile);
    gii = gii.private;
end

% GIFTI metadata (according to the document that defines the format):
MD = { ...
    'AnatomicalStructurePrimary',   ...
    'AnatomicalStructureSecondary', ...
    'Date',                         ...
    'Description',                  ...
    'GeometricType',                ...
    'Intent_code',                  ...
    'Intent_p1',                    ...
    'Intent_p2',                    ...
    'Intent_p3',                    ...
    'Name',                         ...
    'SubjectID',                    ...
    'SurfaceID',                    ...
    'TimeStep',                     ...
    'TopologicalType',              ...
    'UniqueID',                     ...
    'Username'  };

% Loop over data arrays:
nDA = numel(gii.data);
hdf = cell(nDA,1);
breakthis = false;
for da = 1:nDA,
    
    % Store in a temporary struct all the relevant information.
    % Interestingly, nearly everything is subsumed by the HDF5 itself and
    % don't need duplication:
    switch gii.data{da}.attributes.DataType,
        case 'NIFTI_TYPE_UINT8',
            hdf{da}.attr.datatype = 'H5T_NATIVE_UINT8'; % Unsigned char
            hdf{da}.data = gii.data{da}.data;
        case 'NIFTI_TYPE_INT32',
            hdf{da}.attr.datatype = 'H5T_NATIVE_INT32'; % Signed int
            hdf{da}.data = gii.data{da}.data;
        case 'NIFTI_TYPE_FLOAT32',
            hdf{da}.attr.datatype = 'H5T_NATIVE_FLOAT'; % Float
            hdf{da}.data = single(gii.data{da}.data);
        otherwise
            error('Unknown GIFTI DataType: ''%s''.', gii.data{da}.attributes.DataType);
    end
    
    % Assemble the data:
    switch gii.data{da}.attributes.Intent,
        case {  'NIFTI_INTENT_GENMATRIX',   ...
                'NIFTI_INTENT_NODE_INDEX',  ...
                'NIFTI_INTENT_NONE',        ...
                'NIFTI_INTENT_VECTOR'  },
            error('Don''t know what to do yet: %s', gii.data{da}.attributes.Intent);
        case {  'NIFTI_INTENT_LABEL',       ...
                'NIFTI_INTENT_POINTSET',    ...
                'NIFTI_INTENT_SHAPE',       ...
                'NIFTI_INTENT_RGB_VECTOR',  ...
                'NIFTI_INTENT_RGBA_VECTOR', ...
                'NIFTI_INTENT_TRIANGLE'  },
            hdf{da}.data = gii.data{da}.data;
        case 'NIFTI_INTENT_TIME_SERIES',
            if nDA > 1,
                siz = [ ...
                    size(gii.data{da}.data,1) ...
                    size(gii.data{da}.data,2) ...
                    size(gii.data{da}.data,3) nDA];
                hdf{1}.data = zeros(siz);
                for t = 1:nDA,
                    hdf{da}.data(:,:,:,t) = gii.data{t}.data;
                end
                hdf(da+1:end) = [];
                breakthis = true;
            else
                hdf{da}.data = gii.data{da}.data;
            end
        otherwise
            if strcmpi(gii.data{da}.attributes.Intent(1:13),'NIFTI_INTENT_'),
                hdf{da}.data = gii.data{da}.data;
            else
                error('Unknown DataArray Intent: %s', gii.data{da}.attributes.Intent);
            end
    end
    
    % In which group to store the data and respective intents:
    switch gii.data{da}.attributes.Intent,
        case 'NIFTI_INTENT_GENMATRIX',
            hdf{da}.attr.intent = 'tensor';
            hdf{da}.dset_name   = 'field';
        case 'NIFTI_INTENT_LABEL',
            hdf{da}.attr.intent = 'label';
            hdf{da}.dset_name   = 'field';
        case 'NIFTI_INTENT_NODE_INDEX',
            hdf{da}.attr.intent = 'nodes';
            hdf{da}.dset_name   = 'other';
        case 'NIFTI_INTENT_POINTSET',
            hdf{da}.attr.intent = 'points';
            hdf{da}.dset_name   = 'points';
        case 'NIFTI_INTENT_RGB_VECTOR',
            hdf{da}.attr.intent = 'rgb';
            hdf{da}.dset_name   = 'field';
        case 'NIFTI_INTENT_RGBA_VECTOR',
            hdf{da}.attr.intent = 'rgba';
            hdf{da}.dset_name   = 'field';
        case 'NIFTI_INTENT_SHAPE',
            hdf{da}.attr.intent = 'scalar';
            hdf{da}.dset_name   = 'field';
        case 'NIFTI_INTENT_TIME_SERIES',
            hdf{da}.attr.intent = 'none';
            hdf{da}.dset_name   = 'field';
        case 'NIFTI_INTENT_TRIANGLE',
            hdf{da}.attr.intent = 'triangles';
            hdf{da}.dset_name   = 'facet';
        case 'NIFTI_INTENT_VECTOR',
            hdf{da}.attr.intent = 'vector';
            hdf{da}.dset_name   = 'field';
        case 'NIFTI_INTENT_NONE',
            hdf{da}.attr.intent = 'none';
            hdf{da}.dset_name   = 'other';
        otherwise
            if strcmpi(gii.data{da}.attributes.Intent(1:13),'NIFTI_INTENT_'),
                hdf{da}.attr.intent = lower(gii.data{da}.attributes.Intent(14:end));
                hdf{da}.dset_name   = 'field';
            else
                error('Unknown DataArray Intent: %s', gii.data{da}.attributes.Intent);
            end
    end
    
    % Get the affine transformation matrix. Issue here is that the GIFTI
    % allows for multiple such matrices. What to do when there's more than
    % one? Here the approach is to leave the data as is (whatever way it
    % is), and use as the affine whichever combination that allows the
    % highest possible level, in the order specified by the NIFTI header
    % (yes, NIFTI, not GIFTI, because the GIFTI document specifies the
    % NIFTI terms).
    if isfield(gii.data{da},'space') && ~ isempty(gii.data{da}.space),
        if ~ isfield(gii.data{da}.space(end), 'MatrixData'),
            
            % If there is no field "MatrixData", use identity:
            hdf{da}.attr.affine = eye(4);
            
        elseif any(strcmp('NIFTI_XFORM_MNI152', {gii.data{da}.space(:).DataSpace})),
            
            % If the data is already in MNI, do nothing:
            hdf{da}.attr.affine = eye(4);
            
        elseif any(strcmp('NIFTI_XFORM_MNI152', {gii.data{da}.space(:).TransformedSpace})),
            
            % If there is a transformation that put it into MNI, use it:
            idx =  strcmp('NIFTI_XFORM_MNI152', {gii.data{da}.space(:).TransformedSpace});
            hdf{da}.attr.affine = gii.data{da}.space(idx).MatrixData;
            
        elseif any(strcmp('NIFTI_XFORM_TALAIRACH', {gii.data{da}.space(:).DataSpace})),
            
            % Otherwise, if the data is already in Talairach, do nothing:
            hdf{da}.attr.affine = eye(4);
            
        elseif any(strcmp('NIFTI_XFORM_TALAIRACH', {gii.data{da}.space(:).TransformedSpace})),
            
            % Otherwise, if there is a transformation that put it into Talairach, use it:
            idx =  strcmp('NIFTI_XFORM_TALAIRACH', {gii.data{da}.space(:).TransformedSpace});
            hdf{da}.attr.affine = gii.data{da}.space(idx).MatrixData;
            
        elseif any(strcmp('NIFTI_XFORM_ALIGNED_ANAT', {gii.data{da}.space(:).DataSpace})),
            
            % Otherwise, if the data is already in Talairach, do nothing:
            hdf{da}.attr.affine = eye(4);
            
        elseif any(strcmp('NIFTI_XFORM_ALIGNED_ANAT', {gii.data{da}.space(:).TransformedSpace})),
            
            % Otherwise, if there is a transformation that put it into Talairach, use it:
            idx =  strcmp('NIFTI_XFORM_ALIGNED_ANAT', {gii.data{da}.space(:).TransformedSpace});
            hdf{da}.attr.affine = gii.data{da}.space(idx).MatrixData;
            
        elseif any(strcmp('NIFTI_XFORM_SCANNER_ANAT', {gii.data{da}.space(:).DataSpace})),
            
            % Otherwise, if the data is already in Talairach, do nothing:
            hdf{da}.attr.affine = eye(4);
            
        elseif any(strcmp('NIFTI_XFORM_SCANNER_ANAT', {gii.data{da}.space(:).TransformedSpace})),
            
            % Otherwise, if there is a transformation that put it into Talairach, use it:
            idx =  strcmp('NIFTI_XFORM_SCANNER_ANAT',{gii.data{da}.space(:).TransformedSpace});
            hdf{da}.attr.affine = gii.data{da}.space(idx).MatrixData;
            
        else
            
            % If none of these (this covers the 'NIFTI_XFORM_UNKNOWN'), use whatever that is:
            hdf{da}.attr.affine = gii.data{da}.space(end).MatrixData;
        end
    end
    
    % For the label data, create the table with the indices:
    if strcmp(gii.data{da}.attributes.Intent,'NIFTI_INTENT_LABEL'),
        nL = numel(gii.label.name);
        hdf{da}.attr.index = cell(nL,2);
        hdf{da}.attr.index(:,1) = mat2cell(gii.label.key(:),ones(nL,1));
        hdf{da}.attr.index(:,2) = gii.label.name(:);
    end
    
    % Deal with the metadata:
    for md = 1:numel(MD),
        idx = strcmpi({gii.data{da}.metadata(:).name}, MD{md});
        if any(idx),
            hdf{da}.attr.(gii.data{da}.metadata(idx).name) = ...
                gii.data{da}.metadata(idx).value;
        end
    end
    
    % For the timeseries case above, no need to continue the loop once the
    % first has been dealt with.
    if breakthis,
        break
    end
end

% Add a digit at the end of each dataspace name, to avoid name collisions.
dsnames = struct;
for da = 1:numel(hdf),
    if ~ isfield(dsnames, hdf{da}.dset_name),
        dsnames.(hdf{da}.dset_name) = 0;
    end
    dsnames.(hdf{da}.dset_name) = dsnames.(hdf{da}.dset_name) + 1;
    hdf{da}.dset_name = sprintf('%s%d', hdf{da}.dset_name, dsnames.(hdf{da}.dset_name));
end
