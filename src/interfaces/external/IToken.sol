pragma solidity 0.6.7;

interface IToken {
  function mint(address _account, uint256 _amount) external;
  function approve(address _account, uint256 _amount) external returns (bool _success);
  function balanceOf(address _account) external view returns (uint256 _balance);
  function move(address _source, address _destination, uint256 _amount) external;
  function burn(address _account, uint256 _amount) external;
  function transferFrom(address _from, address _to, uint256 _amount) external;
}
