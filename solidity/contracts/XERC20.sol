// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {IXERC20} from 'interfaces/IXERC20.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import 'forge-std/console.sol';

contract XERC20 is ERC20, Ownable, IXERC20, ERC20Permit {
  /**
   * @notice The duration it takes for the limits to fully replenish
   */
  uint256 private constant _DURATION = 1 days;

  uint256 private constant _SET_LOCKBOX_EVENT_SIG = 0xfa2e15ea41196e438f0593ecdd6036acd83bdfcd39d627b77c17eab43f376a39;

  uint256 private constant _SET_LIMITS_EVENT_SIG = 0x7c80aa9fdbfaf9615e4afc7f5f722e265daca5ccc655360fa5ccacf9c267936d;

  /**
   * @notice The address of the factory which deployed this contract
   */
  address public immutable FACTORY;

  /**
   * @notice The address of the lockbox contract
   */
  address public lockbox;

  /**
   * @notice Maps bridge address to bridge configurations
   */
  mapping(address => Bridge) public bridges;

  /**
   * @notice Constructs the initial config of the XERC20
   *
   * @param _name The name of the token
   * @param _symbol The symbol of the token
   * @param _factory The factory which deployed this contract
   */

  constructor(
    string memory _name,
    string memory _symbol,
    address _factory
  ) ERC20(string.concat('x', _name), string.concat('x', _symbol)) ERC20Permit(string.concat('x', _name)) {
    _transferOwnership(_factory);
    FACTORY = _factory;
  }

  /**
   * @notice Mints tokens for a user
   * @dev Can only be called by a bridge
   * @param _user The address of the user who needs tokens minted
   * @param _amount The amount of tokens being minted
   */

  function mint(address _user, uint256 _amount) public {
    bytes32 location = keccak256(abi.encode(msg.sender, 9));

    assembly {
      if iszero(eq(caller(), sload(lockbox.slot))) {
      let _currentLimit := sload(add(location, 3))
      let _maxLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 1))
      let m := mload(0x40)

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _maxLimit))) {
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _currentLimit := mload(m) }
      }

      if lt(_currentLimit, _amount) {
        revert(0,0)
      }

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        mstore(add(m, 0x20), add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(add(m, 0x20)), _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(mload(add(m, 0x20)), _maxLimit)) { _currentLimit := mload(add(m, 0x20)) }
      }

      if gt(_amount, _currentLimit) {
        // Revert cause of underflow
        revert(0, 0)
      }

      sstore(add(location, 3), sub(_currentLimit, _amount))

      sstore(location, timestamp())
    }
    }
        _mint(_user, _amount);
    }

  /**
   * @notice Burns tokens for a user
   * @dev Can only be called by a bridge
   * @param _user The address of the user who needs tokens burned
   * @param _amount The amount of tokens being burned
   */

  function burn(address _user, uint256 _amount) public {
    bytes32 location = keccak256(abi.encode(msg.sender, 9));

    assembly {
      if iszero(eq(caller(), sload(lockbox.slot))) {
      let _currentLimit := sload(add(location, 7))
      let _maxLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 5))
      let m := mload(0x40)

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _maxLimit))) {
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _currentLimit := mload(m) }
      }

      if lt(_currentLimit, _amount) {
        revert(0,0)
      }

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        mstore(add(m, 0x20), add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(add(m, 0x20)), _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(mload(add(m, 0x20)), _maxLimit)) { _currentLimit := mload(add(m, 0x20)) }
      }

      if gt(_amount, _currentLimit) {
        // Revert cause of underflow
        revert(0, 0)
      }

      sstore(add(location, 7), sub(_currentLimit, _amount))

      sstore(location, timestamp())
    }
    }
        _burn(_user, _amount);
  }

  /**
   * @notice Sets the lockbox address
   *
   * @param _lockbox The address of the lockbox
   */

  function setLockbox(address _lockbox) public {
    address fact = FACTORY;
    assembly {
      if iszero(eq(caller(), fact)) { revert(0, 0) }
      sstore(lockbox.slot, _lockbox)

      log2(0, 0, _SET_LOCKBOX_EVENT_SIG, _lockbox) // Log the event with one topic
    }
  }

  /**
   * @notice Updates the limits of any bridge
   * @dev Can only be called by the owner
   * @param _mintingLimit The updated minting limit we are setting to the bridge
   * @param _burningLimit The updated burning limit we are setting to the bridge
   * @param _bridge The address of the bridge we are setting the limits too
   */
  function setLimits(address _bridge, uint256 _mintingLimit, uint256 _burningLimit) external onlyOwner {
    bytes32 location = keccak256(abi.encode(_bridge, 9));

    assembly {
      let _currentMintingLimit := sload(add(location, 3))
      let _oldMintingLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _mintingRatePerSecond := sload(add(location, 1))

      let m := mload(0x40)

      if eq(_currentMintingLimit, _oldMintingLimit) { _currentMintingLimit := _oldMintingLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentMintingLimit := _oldMintingLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentMintingLimit, _oldMintingLimit))) {
        mstore(add(m, 0x20), add(mul(sub(timestamp(), _timestamp), _mintingRatePerSecond), _currentMintingLimit))

        if gt(mload(add(m, 0x20)), _oldMintingLimit) { _currentMintingLimit := _oldMintingLimit }

        if iszero(gt(mload(add(m, 0x20)), _oldMintingLimit)) { _currentMintingLimit := mload(add(m, 0x20)) }
      }

      if iszero(eq(_oldMintingLimit, _mintingLimit)) {
        if gt(_oldMintingLimit, _mintingLimit) {
          mstore(m, sub(_oldMintingLimit, _mintingLimit))

          if iszero(gt(_currentMintingLimit, mload(m))) { sstore(add(location, 3), 0) }

          if gt(_currentMintingLimit, mload(m)) { sstore(add(location, 3), sub(_currentMintingLimit, mload(m))) }
        }

        if iszero(gt(_oldMintingLimit, _mintingLimit)) {
          mstore(m, sub(_mintingLimit, _oldMintingLimit))

          sstore(add(location, 3), add(_currentMintingLimit, mload(m)))
        }
      }
      sstore(add(location, 1), div(_mintingLimit, _DURATION))
      sstore(location, timestamp())
      sstore(add(location, 2), _mintingLimit)

      let _currentLimit := sload(add(location, 7))
      let _oldLimit := sload(add(location, 6))
      let _ratePerSecond := sload(add(location, 5))

      if eq(_currentLimit, _oldLimit) { _currentLimit := _oldLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _oldLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _oldLimit))) {
        mstore(sub(m, 0x20), add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(sub(m, 0x20)), _oldLimit) { _currentLimit := _oldLimit }

        if iszero(gt(mload(sub(m, 0x20)), _oldLimit)) { _currentLimit := mload(sub(m, 0x20)) }
      }

      if iszero(eq(_oldLimit, _burningLimit)) {
        if gt(_oldLimit, _burningLimit) {
          mstore(sub(m, 0x40), sub(_oldLimit, _burningLimit))

          if iszero(gt(_currentLimit, mload(sub(m, 0x40)))) { sstore(add(location, 7), 0) }

          if gt(_currentLimit, mload(sub(m, 0x40))) { sstore(add(location, 7), sub(_currentLimit, mload(sub(m, 0x40)))) }
        }

        if iszero(gt(_oldLimit, _burningLimit)) {
          mstore(sub(m, 0x40), sub(_burningLimit, _oldLimit))

          sstore(add(location, 7), add(_currentLimit, mload(sub(m, 0x40))))
        }
      }
      
      sstore(add(location, 5), div(_burningLimit, _DURATION))
      sstore(add(location, 6), _burningLimit)

      log4(0, 0, _SET_LIMITS_EVENT_SIG, _mintingLimit, _burningLimit, _bridge) // Log the event with one topic
    }
  }

  /**
   * @notice Returns the max limit of a bridge
   *
   * @param _bridge the bridge we are viewing the limits of
   * @return _limit The limit the bridge has
   */

  function mintingMaxLimitOf(address _bridge) public view returns (uint256 _limit) {
    // Get location (storage is slot 9)
    bytes32 location = keccak256(abi.encode(_bridge, 9));
    assembly {
      _limit := sload(add(location, 2))
    }
  }

  /**
   * @notice Returns the max limit of a bridge
   *
   * @param _bridge the bridge we are viewing the limits of
   * @return _limit The limit the bridge has
   */

  function burningMaxLimitOf(address _bridge) public view returns (uint256 _limit) {
    // Get location (storage is slot 9)
    bytes32 location = keccak256(abi.encode(_bridge, 9));
    assembly {
      _limit := sload(add(location, 6))
    }
  }

  /**
   * @notice Returns the current limit of a bridge
   *
   * @param _bridge the bridge we are viewing the limits of
   * @return _limit The limit the bridge has
   */

  function mintingCurrentLimitOf(address _bridge) public view returns (uint256 _limit) {
    bytes32 location = keccak256(abi.encode(_bridge, 9));

    assembly {
      let _currentLimit := sload(add(location, 3))
      let _maxLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 1))

      if eq(_currentLimit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _maxLimit))) {
        let m := mload(0x40)
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _limit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _limit := mload(m) }
      }
    }
  }

  /**
   * @notice Returns the current limit of a bridge
   *
   * @param _bridge the bridge we are viewing the limits of
   * @return _limit The limit the bridge has
   */

  function burningCurrentLimitOf(address _bridge) public view returns (uint256 _limit) {
    bytes32 location = keccak256(abi.encode(_bridge, 9));

    assembly {
      let _currentLimit := sload(add(location, 7))
      let _maxLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 5))

      if eq(_currentLimit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _maxLimit))) {
        let m := mload(0x40)
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _limit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _limit := mload(m) }
      }
    }
  }

  /**
   * @notice Uses the limit of any bridge
   * @param _change The change in the limit
   * @param _bridge The address of the bridge who is being changed
   */

  function _useMinterLimits(uint256 _change, address _bridge) internal {
    bytes32 location = keccak256(abi.encode(_bridge, 9));

    assembly {
      let _currentLimit := sload(add(location, 3))
      let _maxLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 1))
      let _limit

      if eq(_limit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        let m := mload(0x40)
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _limit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _limit := mload(m) }
      }

      if gt(_change, _limit) {
        // Revert cause of underflow
        revert(0, 0)
      }

      sstore(add(location, 3), sub(_limit, _change))

      sstore(location, timestamp())
    }
  }

  /**
   * @notice Uses the limit of any bridge
   * @param _change The change in the limit
   * @param _bridge The address of the bridge who is being changed
   */

  function _useBurnerLimits(uint256 _change, address _bridge) internal {
    bytes32 location = keccak256(abi.encode(_bridge, 9));

    assembly {
      let _currentLimit := sload(add(location, 7))
      let _maxLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 5))
      let _limit

      if eq(_limit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        let m := mload(0x40)
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _limit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _limit := mload(m) }
      }

      if gt(_change, _limit) {
        // Revert cause of underflow
        revert(0, 0)
      }

      sstore(add(location, 7), sub(_limit, _change))

      sstore(location, timestamp())
    }
  }

  /**
   * @notice Updates the limit of any bridge
   * @dev Can only be called by the owner
   * @param _limit The updated limit we are setting to the bridge
   * @param _bridge The address of the bridge we are setting the limit too
   */

  function _changeMinterLimit(uint256 _limit, address _bridge) internal {
    bytes32 location = keccak256(abi.encode(_bridge, 9));

    assembly {
      let _currentLimit := sload(add(location, 3))
      let _oldLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 1))

      let m := mload(0x40)

      if eq(_currentLimit, _oldLimit) { _currentLimit := _oldLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _oldLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _oldLimit))) {
        mstore(add(m, 0x20), add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(add(m, 0x20)), _oldLimit) { _currentLimit := _oldLimit }

        if iszero(gt(mload(add(m, 0x20)), _oldLimit)) { _currentLimit := mload(add(m, 0x20)) }
      }

      if iszero(eq(_oldLimit, _limit)) {
        if gt(_oldLimit, _limit) {
          mstore(m, sub(_oldLimit, _limit))

          if iszero(gt(_currentLimit, mload(m))) { sstore(add(location, 3), 0) }

          if gt(_currentLimit, mload(m)) { sstore(add(location, 3), sub(_currentLimit, mload(m))) }
        }

        if iszero(gt(_oldLimit, _limit)) {
          mstore(m, sub(_limit, _oldLimit))

          sstore(add(location, 3), add(_currentLimit, mload(m)))
        }
      }
      sstore(add(location, 1), div(_limit, _DURATION))
      sstore(location, timestamp())
      sstore(add(location, 2), _limit)
    }
  }

  /**
   * @notice Updates the limit of any bridge
   * @dev Can only be called by the owner
   * @param _limit The updated limit we are setting to the bridge
   * @param _bridge The address of the bridge we are setting the limit too
   */

  function _changeBurnerLimit(uint256 _limit, address _bridge) internal {
    bytes32 location = keccak256(abi.encode(_bridge, 9));

    assembly {
      let _currentLimit := sload(add(location, 7))
      let _oldLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 5))

      let m := mload(0x40)

      if eq(_currentLimit, _oldLimit) { _currentLimit := _oldLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _oldLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _oldLimit))) {
        mstore(add(m, 0x20), add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(add(m, 0x20)), _oldLimit) { _currentLimit := _oldLimit }

        if iszero(gt(mload(add(m, 0x20)), _oldLimit)) { _currentLimit := mload(add(m, 0x20)) }
      }

      if iszero(eq(_oldLimit, _limit)) {
        if gt(_oldLimit, _limit) {
          mstore(m, sub(_oldLimit, _limit))

          if iszero(gt(_currentLimit, mload(m))) { sstore(add(location, 7), 0) }

          if gt(_currentLimit, mload(m)) { sstore(add(location, 7), sub(_currentLimit, mload(m))) }
        }

        if iszero(gt(_oldLimit, _limit)) {
          mstore(m, sub(_limit, _oldLimit))

          sstore(add(location, 7), add(_currentLimit, mload(m)))
        }
      }
      sstore(add(location, 5), div(_limit, _DURATION))
      sstore(location, timestamp())
      sstore(add(location, 6), _limit)
    }
  }

  /**
   * @notice Updates the current limit
   *
   * @param _limit The new limit
   * @param _oldLimit The old limit
   * @param _currentLimit The current limit
   */

  function _calculateNewCurrentLimit(
    uint256 _limit,
    uint256 _oldLimit,
    uint256 _currentLimit
  ) internal pure returns (uint256 _newCurrentLimit) {
    assembly {
      if eq(_oldLimit, _limit) { _newCurrentLimit := _currentLimit }

      if iszero(eq(_oldLimit, _limit)) {
        let memPntr := mload(0x40)

        if gt(_oldLimit, _limit) {
          mstore(memPntr, sub(_oldLimit, _limit))
          if iszero(gt(_currentLimit, mload(memPntr))) { _newCurrentLimit := 0 }

          if gt(_currentLimit, mload(memPntr)) { _newCurrentLimit := sub(_currentLimit, mload(memPntr)) }
        }

        if iszero(gt(_oldLimit, _limit)) {
          mstore(memPntr, sub(_limit, _oldLimit))
          _newCurrentLimit := add(_currentLimit, mload(memPntr))
        }
      }
    }
  }

  /**
   * @notice Gets the current limit
   *
   * @param _currentLimit The current limit
   * @param _maxLimit The max limit
   * @param _timestamp The timestamp of the last update
   * @param _ratePerSecond The rate per second
   */

  function _getCurrentLimit(
    uint256 _currentLimit,
    uint256 _maxLimit,
    uint256 _timestamp,
    uint256 _ratePerSecond
  ) internal view returns (uint256 _limit) {
    assembly {
      if eq(_limit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        let m := mload(0x40)
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _limit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _limit := mload(m) }
      }
    }
  }

  /**
   * @notice Internal function for burning tokens
   *
   * @param _caller The caller address
   * @param _user The user address
   * @param _amount The amount to burn
   */

  function _burnWithCaller(address _caller, address _user, uint256 _amount) internal {
  bytes32 location = keccak256(abi.encode(_caller, 9));

    assembly {
      if iszero(eq(caller(), sload(lockbox.slot))) {
      let _currentLimit := sload(add(location, 7))
      let _maxLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 5))
      let m := mload(0x40)

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _maxLimit))) {
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _currentLimit := mload(m) }
      }

      if lt(_currentLimit, _amount) {
        revert(0,0)
      }

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        mstore(add(m, 0x20), add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(add(m, 0x20)), _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(mload(add(m, 0x20)), _maxLimit)) { _currentLimit := mload(add(m, 0x20)) }
      }

      if gt(_amount, _currentLimit) {
        // Revert cause of underflow
        revert(0, 0)
      }

      sstore(add(location, 7), sub(_currentLimit, _amount))

      sstore(location, timestamp())
    }
    }
        _burn(_user, _amount);
  }

  /**
   * @notice Internal function for minting tokens
   *
   * @param _caller The caller address
   * @param _user The user address
   * @param _amount The amount to mint
   */

  function _mintWithCaller(address _caller, address _user, uint256 _amount) internal {
    bytes32 location = keccak256(abi.encode(_caller, 9));

    assembly {
      if iszero(eq(caller(), sload(lockbox.slot))) {
      let _currentLimit := sload(add(location, 3))
      let _maxLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := sload(add(location, 1))
      let m := mload(0x40)

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _maxLimit))) {
        mstore(m, add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(m), _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(mload(m), _maxLimit)) { _currentLimit := mload(m) }
      }

      if lt(_currentLimit, _amount) {
        revert(0,0)
      }

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        mstore(add(m, 0x20), add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit))

        if gt(mload(add(m, 0x20)), _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(mload(add(m, 0x20)), _maxLimit)) { _currentLimit := mload(add(m, 0x20)) }
      }

      if gt(_amount, _currentLimit) {
        // Revert cause of underflow
        revert(0, 0)
      }

      sstore(add(location, 3), sub(_currentLimit, _amount))

      sstore(location, timestamp())
    }
    }
        _mint(_user, _amount);
    }
  
}
