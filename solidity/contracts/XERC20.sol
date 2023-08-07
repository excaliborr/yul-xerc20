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

  uint256 private constant _SET_LIMITS_EVENT_SIG =  0x93f3bbfe8cfb354ec059175107653f49f6eb479a8622a7d83866ea015435c944;

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
  uint256 constant private _BRIDGES_SLOT = 0xcbc4e5fb;

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
    assembly {
      if iszero(eq(caller(), sload(lockbox.slot))) {
      mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, caller())
      let location := keccak256(0x0c, 0x20)
      let _currentLimit := sload(add(location, 3))
      let _maxLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_maxLimit, _DURATION)

      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
       let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _currentLimit := calculatedLimit }
      }

      if lt(_currentLimit, _amount) {
        mstore(0x00, 0x0b6842aa) // IXERC20_NotHighEnoughLimits revert
        revert(0x1c, 0x04)
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

    assembly {
      if iszero(eq(caller(), sload(lockbox.slot))) {
                    mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, caller())
      let location := keccak256(0x0c, 0x20)
      let _currentLimit := sload(add(location, 7))
      let _maxLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_maxLimit, _DURATION)

            if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _currentLimit := calculatedLimit }
      }

      if lt(_currentLimit, _amount) {
        mstore(0x00, 0x0b6842aa) // IXERC20_NotHighEnoughLimits revert
        revert(0x1c, 0x04)
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
      if iszero(eq(caller(), fact)) { 
        mstore(0x0c, 0x2029e525) // IXERC20_NotFactory revert
        revert(0x1c, 0x04)
         }
      sstore(lockbox.slot, _lockbox)
      
      mstore(0x00, _lockbox)
      log1(0x00, 0x20, _SET_LOCKBOX_EVENT_SIG) // Log the event with one topic
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

    assembly {
      mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)

      let _currentMintingLimit := sload(add(location, 3))
      let _oldMintingLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _mintingRatePerSecond := div(_oldMintingLimit, _DURATION)

      let m := mload(0x40)

      if eq(_currentMintingLimit, _oldMintingLimit) { _currentMintingLimit := _oldMintingLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentMintingLimit := _oldMintingLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentMintingLimit, _oldMintingLimit))) {
        let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _mintingRatePerSecond), _currentMintingLimit)

        if gt(calculatedLimit, _oldMintingLimit) { _currentMintingLimit := _oldMintingLimit }

        if iszero(gt(calculatedLimit, _oldMintingLimit)) { _currentMintingLimit := calculatedLimit }
      }

      if iszero(eq(_oldMintingLimit, _mintingLimit)) {
        if gt(_oldMintingLimit, _mintingLimit) {
         let difference := sub(_oldMintingLimit, _mintingLimit)

          if iszero(gt(_currentMintingLimit, difference)) { sstore(add(location, 3), 0) }

          if gt(_currentMintingLimit, difference) { sstore(add(location, 3), sub(_currentMintingLimit, difference)) }
        }

        if iszero(gt(_oldMintingLimit, _mintingLimit)) {
          mstore(m, sub(_mintingLimit, _oldMintingLimit))
          mstore(m, add(_currentMintingLimit, mload(m)))
          if gt(_currentMintingLimit, mload(m)) {
            // Overflow
            revert(0,0)
           }
          sstore(add(location, 3), mload(m))
        }
      }
      // sstore(add(location, 1), div(_mintingLimit, _DURATION))
      sstore(location, timestamp())
      sstore(add(location, 2), _mintingLimit)

      let _currentLimit := sload(add(location, 7))
      let _oldLimit := sload(add(location, 6))
      let _ratePerSecond := div(_oldLimit, _DURATION)
      let _burningTimestamp := sload(add(location, 4))

      if eq(_currentLimit, _oldLimit) { _currentLimit := _oldLimit }

      if iszero(gt(add(_burningTimestamp, _DURATION), timestamp())) { _currentLimit := _oldLimit }

      if iszero(eq(gt(add(_burningTimestamp, _DURATION), timestamp()), eq(_currentLimit, _oldLimit))) {
       let calculatedLimit := add(mul(sub(timestamp(), _burningTimestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _oldLimit) { _currentLimit := _oldLimit }

        if iszero(gt(calculatedLimit, _oldLimit)) { _currentLimit := calculatedLimit }
      }

      if iszero(eq(_oldLimit, _burningLimit)) {
        if gt(_oldLimit, _burningLimit) {
          mstore(sub(m, 0x40), sub(_oldLimit, _burningLimit))

          if iszero(gt(_currentLimit, mload(sub(m, 0x40)))) { sstore(add(location, 7), 0) }

          if gt(_currentLimit, mload(sub(m, 0x40))) { sstore(add(location, 7), sub(_currentLimit, mload(sub(m, 0x40)))) }
        }

        if iszero(gt(_oldLimit, _burningLimit)) {
          mstore(sub(m, 0x40), sub(_burningLimit, _oldLimit))
          mstore(sub(m, 0x40), add(_currentLimit, mload(sub(m, 0x40))))
          if gt(_currentLimit, mload(sub(m, 0x40))) {
            // Overflow
            revert(0,0)
           }
          sstore(add(location, 7), mload(sub(m, 0x40)))
        }
      }
      
      sstore(add(location, 6), _burningLimit)
      sstore(add(location, 4), timestamp())

      mstore(0x00, _mintingLimit)
      mstore(0x20, _burningLimit)
      log2(0x00, 0x40, _SET_LIMITS_EVENT_SIG, _bridge) // Log the event with one topic
    }
  }

  /**
   * @notice Returns the max limit of a bridge
   *
   * @param _bridge the bridge we are viewing the limits of
   * @return _limit The limit the bridge has
   */

  function mintingMaxLimitOf(address _bridge) public view returns (uint256 _limit) {
    assembly {
            mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)
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
    assembly {
            mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)
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
    assembly {
            mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)

      let _currentLimit := sload(add(location, 3))
      let _maxLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_maxLimit, _DURATION)

      if eq(_currentLimit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _maxLimit))) {
        let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _limit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _limit := calculatedLimit }
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
    assembly {
            mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)

      let _currentLimit := sload(add(location, 7))
      let _maxLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_maxLimit, _DURATION)

      if eq(_currentLimit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if iszero(eq(gt(add(_timestamp, _DURATION), timestamp()), eq(_currentLimit, _maxLimit))) {
        let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _limit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _limit := calculatedLimit }
      }
    }
  }

  /**
   * @notice Uses the limit of any bridge
   * @param _change The change in the limit
   * @param _bridge The address of the bridge who is being changed
   */

  function _useMinterLimits(uint256 _change, address _bridge) internal {
    assembly {

                  mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)

      let _currentLimit := sload(add(location, 3))
      let _maxLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_maxLimit, _DURATION)
      let _limit

      if eq(_limit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _limit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _limit := calculatedLimit }
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
    assembly {
                  mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)

      let _currentLimit := sload(add(location, 7))
      let _maxLimit := sload(add(location, 6))
      let _timestamp := sload(add(location, 4))
      let _ratePerSecond := div(_maxLimit, _DURATION)
      let _limit

      if eq(_limit, _maxLimit) { _limit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _limit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _limit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _limit := calculatedLimit }
      }

      if gt(_change, _limit) {
        // Revert cause of underflow
        revert(0, 0)
      }

      sstore(add(location, 7), sub(_limit, _change))

      sstore(add(location, 4), timestamp())
    }
  }

  /**
   * @notice Updates the limit of any bridge
   * @dev Can only be called by the owner
   * @param _limit The updated limit we are setting to the bridge
   * @param _bridge The address of the bridge we are setting the limit too
   */

  function _changeMinterLimit(uint256 _limit, address _bridge) internal {
    assembly {

                  mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)
      let _currentLimit := sload(add(location, 3))
      let _oldLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_oldLimit, _DURATION)

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
          mstore(add(m, 0x20), add(_currentLimit, mload(m)))
          if gt(_currentLimit, mload(add(m, 0x20))) {
            // Overflow
            revert(0,0)
           }
          sstore(add(location, 3), mload(add(m, 0x20)))
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

    assembly {
                  mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _bridge)
      let location := keccak256(0x0c, 0x20)

      let _currentLimit := sload(add(location, 7))
      let _oldLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_oldLimit, _DURATION)

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
          mstore(add(m, 0x20), add(_currentLimit, mload(m)))
          if gt(_currentLimit, mload(add(m, 0x20))) {
            // Overflow
            revert(0,0)
           }
          sstore(add(location, 7), mload(add(m, 0x20)))
        }
      }
      // sstore(add(location, 5), div(_limit, _DURATION))
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
          mstore(add(memPntr, 0x20), add(_currentLimit, mload(memPntr)))
          if gt(_currentLimit, mload(add(memPntr, 0x20))) {
            // Overflow
            revert(0,0)
           }
          _newCurrentLimit := mload(add(memPntr, 0x20))
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
        
       let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _limit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _limit := calculatedLimit }
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

    assembly {
      if iszero(eq(_caller, sload(lockbox.slot))) {
                    mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _caller)
      let location := keccak256(0x0c, 0x20)
      let _currentLimit := sload(add(location, 7))
      let _maxLimit := sload(add(location, 6))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_maxLimit, _DURATION)

            if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
        let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _currentLimit := calculatedLimit }
      }

      if lt(_currentLimit, _amount) {
        mstore(0x00, 0x0b6842aa) // IXERC20_NotHighEnoughLimits revert
        revert(0x1c, 0x04)
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
    assembly {
      if iszero(eq(_caller, sload(lockbox.slot))) {
                            mstore(0x0c, _BRIDGES_SLOT)
      mstore(0x00, _caller)
      let location := keccak256(0x0c, 0x20)

      let _currentLimit := sload(add(location, 3))
      let _maxLimit := sload(add(location, 2))
      let _timestamp := sload(location)
      let _ratePerSecond := div(_maxLimit, _DURATION)
      
      if eq(_currentLimit, _maxLimit) { _currentLimit := _maxLimit }

      if iszero(gt(add(_timestamp, _DURATION), timestamp())) { _currentLimit := _maxLimit }

      if gt(add(_timestamp, _DURATION), timestamp()) {
       let calculatedLimit := add(mul(sub(timestamp(), _timestamp), _ratePerSecond), _currentLimit)

        if gt(calculatedLimit, _maxLimit) { _currentLimit := _maxLimit }

        if iszero(gt(calculatedLimit, _maxLimit)) { _currentLimit := calculatedLimit }
      }

      if lt(_currentLimit, _amount) {
        mstore(0x00, 0x0b6842aa) // IXERC20_NotHighEnoughLimits revert
        revert(0x1c, 0x04)
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
