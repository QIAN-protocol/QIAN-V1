pragma solidity 0.6.2;

interface IAuthentication {
    function accessible(
        address sender,
        address code,
        bytes4 sig
    ) external view returns (bool);
}
