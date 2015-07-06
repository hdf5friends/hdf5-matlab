function nii = niihdrread(filename)
% Read a NIFTI-1 or NIFTI-2 file.
% Currently no extensions are supported (that is, no CIFTI).
% Must be a single .nii file (not .hdr/.img pair).
% Must be uncompressed.
%
% nii = niihdrread(filename)
%
% - filename   : File to be read.
% - nii        : Struct containing the content of the file.
%
% _____________________________________
% Anderson M. Winkler
% FMRIB / Univ. of Oxford
% Nov/2012 (first version)
% Jul/2015 (this version)
% http://brainder.org

% Read the first 4 bytes to determine endianness and version:
fid = fopen(filename, 'r', 'l');
sizeof_hdr = fread(fid, 1, 'int32=>int32');
fclose(fid);
if sizeof_hdr == 348,
    niftiversion = 1;
    endianness   = 'l';
elseif sizeof_hdr == 540,
    niftiversion = 2;
    endianness   = 'l';
elseif sizeof_hdr == 1543569408,
    niftiversion = 1;
    endianness   = 'b';
elseif sizeof_hdr == 469893120,
    niftiversion = 2;
    endianness   = 'b';
end

% These two fields aren't part of the actual header
% and shouldn't be saved:
nii.hdr.niftiversion = niftiversion;
nii.hdr.endianness   = endianness;

% Then open the file again, now knowing what to do:
fid = fopen(filename, 'r', endianness);
if niftiversion == 1,
    
    % NIFTI-1:
    nii.hdr.sizeof_hdr     = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.data_type      = fread(fid, 10,'int8=>int8'      );
    nii.hdr.db_name        = fread(fid, 18,'int8=>char'      )';
    nii.hdr.extents        = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.session_error  = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.regular        = fread(fid, 1, 'int8=>int8'      );
    nii.hdr.dim_info       = fread(fid, 1, 'int8=>int8'      );
    nii.hdr.dim            = fread(fid, 8, 'int16=>int16'    );
    nii.hdr.intent_p1      = fread(fid, 1, 'float32=>float32');
    nii.hdr.intent_p2      = fread(fid, 1, 'float32=>float32');
    nii.hdr.intent_p3      = fread(fid, 1, 'float32=>float32');
    nii.hdr.intent_code    = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.datatype       = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.bitpix         = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.slice_start    = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.pixdim         = fread(fid, 8, 'float32=>float32');
    nii.hdr.vox_offset     = fread(fid, 1, 'float32=>float32');
    nii.hdr.scl_slope      = fread(fid, 1, 'float32=>float32');
    nii.hdr.scl_inter      = fread(fid, 1, 'float32=>float32');
    nii.hdr.slice_end      = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.slice_code     = fread(fid, 1, 'int8=>int8'      );
    nii.hdr.xyzt_units     = fread(fid, 1, 'int8=>int8'      );
    nii.hdr.cal_max        = fread(fid, 1, 'float32=>float32');
    nii.hdr.cal_min        = fread(fid, 1, 'float32=>float32');
    nii.hdr.slice_duration = fread(fid, 1, 'float32=>float32');
    nii.hdr.toffset        = fread(fid, 1, 'float32=>float32');
    nii.hdr.glmax          = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.glmin          = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.descrip        = fread(fid, 80,'int8=>char'      )';
    nii.hdr.aux_file       = fread(fid, 24,'int8=>char'      )';
    nii.hdr.qform_code     = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.sform_code     = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.quatern_b      = fread(fid, 1, 'float32=>float32');
    nii.hdr.quatern_c      = fread(fid, 1, 'float32=>float32');
    nii.hdr.quatern_d      = fread(fid, 1, 'float32=>float32');
    nii.hdr.qoffset_x      = fread(fid, 1, 'float32=>float32');
    nii.hdr.qoffset_y      = fread(fid, 1, 'float32=>float32');
    nii.hdr.qoffset_z      = fread(fid, 1, 'float32=>float32');
    nii.hdr.srow_x         = fread(fid, 4, 'float32=>float32')';
    nii.hdr.srow_y         = fread(fid, 4, 'float32=>float32')';
    nii.hdr.srow_z         = fread(fid, 4, 'float32=>float32')';
    nii.hdr.intent_name    = fread(fid, 16,'int8=>char'      )';
    nii.hdr.magic          = fread(fid, 4, 'int8=>int8'      )';
    nii.hdr.extension      = fread(fid, 4, 'int8=>int8'      );
    
elseif niftiversion == 2,
    
    % NIFTI-2
    nii.hdr.sizeof_hdr     = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.magic          = fread(fid, 8, 'int8=>int8'      )';
    nii.hdr.datatype       = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.bitpix         = fread(fid, 1, 'int16=>int16'    );
    nii.hdr.dim            = fread(fid, 8, 'int64=>double'   );
    nii.hdr.intent_p1      = fread(fid, 1, 'double=>double'  );
    nii.hdr.intent_p2      = fread(fid, 1, 'double=>double'  );
    nii.hdr.intent_p3      = fread(fid, 1, 'double=>double'  );
    nii.hdr.pixdim         = fread(fid, 8, 'double=>double'  );
    nii.hdr.vox_offset     = fread(fid, 1, 'int64=>int64'    );
    nii.hdr.scl_slope      = fread(fid, 1, 'double=>double'  );
    nii.hdr.scl_inter      = fread(fid, 1, 'double=>double'  );
    nii.hdr.cal_max        = fread(fid, 1, 'double=>double'  );
    nii.hdr.cal_min        = fread(fid, 1, 'double=>double'  );
    nii.hdr.slice_duration = fread(fid, 1, 'double=>double'  );
    nii.hdr.toffset        = fread(fid, 1, 'double=>double'  );
    nii.hdr.slice_start    = fread(fid, 1, 'int64=>int64'    );
    nii.hdr.slice_end      = fread(fid, 1, 'int64=>int64'    );
    nii.hdr.descrip        = fread(fid, 80,'int8=>char'      )';
    nii.hdr.aux_file       = fread(fid, 24,'int8=>char'      )';
    nii.hdr.qform_code     = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.sform_code     = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.quatern_b      = fread(fid, 1, 'double=>double'  );
    nii.hdr.quatern_c      = fread(fid, 1, 'double=>double'  );
    nii.hdr.quatern_d      = fread(fid, 1, 'double=>double'  );
    nii.hdr.qoffset_x      = fread(fid, 1, 'double=>double'  );
    nii.hdr.qoffset_y      = fread(fid, 1, 'double=>double'  );
    nii.hdr.qoffset_z      = fread(fid, 1, 'double=>double'  );
    nii.hdr.srow_x         = fread(fid, 4, 'double=>double'  )';
    nii.hdr.srow_y         = fread(fid, 4, 'double=>double'  )';
    nii.hdr.srow_z         = fread(fid, 4, 'double=>double'  )';
    nii.hdr.slice_code     = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.xyzt_units     = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.intent_code    = fread(fid, 1, 'int32=>int32'    );
    nii.hdr.intent_name    = fread(fid, 16,'int8=>char'      )';
    nii.hdr.dim_info       = fread(fid, 1, 'int8=>int8'      );
    nii.hdr.unused_str     = fread(fid, 15,'int8=>char'      )';
    nii.hdr.extension      = fread(fid, 4, 'int8=>int8'      );
end

% This will disappear when extension support is added:
if nii.hdr.extension ~= 0,
    fclose(fid);
    error('NIFTI extensions currently not supported.')
end

% Format string for the various datatypes:
switch nii.hdr.datatype,
    case 1,
        % Bool
        dtype = 'ubit1=>uint8';
        cnt = 1;
    case 2,
        % Unsigned char
        dtype = 'uint8=>uint8';
        cnt = 1;
    case 4,
        % Signed short
        dtype = 'int16=>int16';
        cnt = 1;
    case 8,
        % Signed int
        dtype = 'int32=>int32';
        cnt = 1;
    case 16,
        % Float
        dtype = 'float32=>float32';
        cnt = 1;
    case 32,
        % Complex
        dtype = 'float32=>float32';
        cnt = 2;
    case 64,
        % Double
        dtype = 'float64=>float64';
        cnt = 1;
    case 128,
        % RGB
        dtype = 'uint8=>uint8';
        cnt = 3;
    case 256,
        % Signed char
        dtype = 'int8=>int8';
        cnt = 1;
    case 512,
        % Unsigned short
        dtype = 'uint16=>uint16';
        cnt = 1;
    case 768,
        % Unsigned int
        dtype = 'uint32=>uint32';
        cnt = 1;
    case 1024,
        % Long long
        dtype = 'int64=>int64';
        cnt = 1;
    case 1280,
        % Unsigned long long
        dtype = 'uint64=>uint64';
        cnt = 1;
    case 1792,
        % Double pair
        dtype = 'float64=>float64';
        cnt = 2;
    case 2304,
        % RGBA
        dtype = 'uint8=>uint8';
        cnt = 4;
    otherwise
        error('Datatype %d not supported.', nii.hdr.datatype);
end

% Read the data array & close the file:
tmp = fread(fid, prod(nii.hdr.dim(2:end))*cnt, dtype);
fclose(fid);

% Reorganise in the memory:
if cnt == 1,
    % Most common case, single volume:
    nii.img = reshape(tmp,nii.hdr.dim(2:end)');
else
    tmp = reshape(tmp',[cnt prod(nii.hdr.dim(2:end))]);
    if nii.hdr.datatype == 32,
        % Complex (two volumes, merged as complex).
        nii.img = complex(...
            reshape(tmp(1,:),nii.hdr.dim(2:end)'),...
            reshape(tmp(2,:),nii.hdr.dim(2:end)'));
    elseif any(nii.hdr.datatype == [128 1792 2304]),
        % Other cases, kept separate as a cell array.
        nii.img = cell(cnt,1);
        for c = 1:cnt,
            nii.img{c} = reshape(tmp(c,:), nii.hdr.dim(2:end)');
        end
    end
end
