// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './libs/Math.sol';
import './libs/SafeMath.sol';
import './libs/SafeERC20.sol';
import './libs/Ownable.sol';
import './libs/IRlinkCore.sol';
import './libs/ReentrancyGuard.sol';

interface IOLC {
    function totalHolders() external view returns(uint256);
}

interface IOlcRefReward {
    function sendOlcRewards(address to) external returns(bool);
}

contract OlcRefReward is Ownable,ReentrancyGuard,IOlcRefReward {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //bsc mainnet Rlink Relation: 0x2fbb59aE194c9552d3bC4Aa168E9Ab684f579Fe6
    address public constant rlinkRelation = address(0x2fbb59aE194c9552d3bC4Aa168E9Ab684f579Fe6);
    //bsc mainnet OLC: 0x00cCe21ccC9197A63519f33002A6B3A71B9A9817
    address public constant olc = address(0x00cCe21ccC9197A63519f33002A6B3A71B9A9817);

    uint256 public halveHolderBase = 1000000; 
    uint256 public constant rewardBase = 10000 * 1e18;
    uint256 public constant maxOlcForReward = 55000000000 * 1e18; //55000000000 * 1e18; //55 billions for reward
    uint256 public totalOlcForReward = maxOlcForReward;
    address public immutable olcExchange;

    event HavleHolderBaseChanged(address sender,uint256 oldBase,uint256 newBase);

    constructor(
        address _olcExchange
    ){
        olcExchange = _olcExchange;
        IERC20(olc).safeApprove(rlinkRelation,type(uint256).max);
    }

    function sendOlcRewards(address to) external override returns(bool){
        require(msg.sender == olcExchange,"caller not olcExchange");
        uint256 parentOlcAmount = currentParentReward();
        uint256 grandpaOlcAmount = parentOlcAmount.mul(7).div(10);
        uint256 distributedAmount = IRlinkCore(rlinkRelation).distribute(olc, to, parentOlcAmount.add(grandpaOlcAmount), 0, parentOlcAmount, grandpaOlcAmount);
        require(distributedAmount > 0,"distribute olc rewards failed");
        totalOlcForReward = totalOlcForReward.sub(distributedAmount);

        return true;
    }

    function currentParentReward() public view returns(uint256){
        uint256 parentAmount = calcParentReward(IOLC(olc).totalHolders());
        if(totalOlcForReward < parentAmount.add(parentAmount.mul(7).div(10))){
            return 0;
        }

        return parentAmount;
    }

    function calcParentReward(uint256 accountCount) public view returns(uint256){
        if(accountCount < halveHolderBase){
            return rewardBase;
        }
        uint256 pow = (accountCount).div(halveHolderBase);

        return rewardBase.mul(7 ** pow).div(10 ** pow);
    }

    function totalRewardedOlc() external view returns(uint256){
        return maxOlcForReward.sub(totalOlcForReward);
    }

    function setHalveHolderBase(uint256 newHalveHolderBase) external onlyOwner {
        require(newHalveHolderBase>0,"newHalveHolderBase can not be 0");
        uint256 oldBase = halveHolderBase;
        halveHolderBase = newHalveHolderBase;

        emit HavleHolderBaseChanged(msg.sender, oldBase, newHalveHolderBase);
    }
}