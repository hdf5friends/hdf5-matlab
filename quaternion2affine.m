function aff = quaternion2affine(quatern,pixdim,qoffset)
% Convert a quaternion representation from the NIFTI
% header to a full affine matrix.
%
% aff = quaternion2affine(quatern,pixdim,qoffset)
%
% - quatern   : quatern_* from the header.
% - pixdim    : pixdim(1:4) from the header.
% - qoffset   : qoffset_* from the header.
% - aff       : 4x4 affine matrix.
%
% _____________________________________
% Anderson M. Winkler
% FMRIB / Univ. of Oxford
% Jul/2015
% http://brainder.org

b = quatern(1);
c = quatern(2);
d = quatern(3);
a = sqrt(1 - b^2 - c^2 - d^2);
R = [
    a^2+b^2-c^2-d^2 2*(b*c-a*d) 2*(b*d+a*c);
    2*(b*c+a*d) a^2+c^2-b^2-d^2 2*(c*d-a*b);
    2*(b*d-a*c) 2*(c*d+a*b) a^2+d^2-b^2-c^2];
aff          = eye(4);
aff(1:3,1:3) = R * diag(pixdim(2:4));
aff(3,3)     = aff(3,3) * pixdim(1);
aff(1:3,4)   = qoffset(:);