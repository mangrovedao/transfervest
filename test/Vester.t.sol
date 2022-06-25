// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "semitransferable-token/Token.sol";
import "forge-std/Test.sol";
import "src/Vester.sol";

contract VesterTest is Test {
    uint256 constant public SUPPLY = 1e9 ether;
    address public $owner = address(this);
    Token public token;
    address public $token;
    Vester public vester;
    address public $vester;
    address public $recipient = address(1);

    // Vesting data
    address usr = $recipient;
    uint256 tot = 100 ether;
    uint256 bgn;
    uint256 tau = 10;
    uint256 eta = 0;
    address mgr = $owner;
    bool res = false;
    bool bls = false;

    function setUp() public {
        token = new Token("Token", "TKN", 18, $owner);
        $token = address(token);
        vester = new Vester($owner, $token);
        $vester = address(vester);

        token.setRoleCapability(0, Token.transfer.selector, true);
        token.setRoleCapability(0, Token.transferFrom.selector, true);
        token.setRoleCapability(1, Token.mint.selector, true);

        token.mint($owner, SUPPLY); // Mint 1B tokens to owner.
        token.approve($vester, SUPPLY); // Allow vester to spend tokens.

        // TWENTY_YEARS is needed here to avoid underflow on DssVest contract.
        bgn = block.timestamp + vester.TWENTY_YEARS() + 100;
        vm.warp(block.timestamp + vester.TWENTY_YEARS());
        vester.file("cap", type(uint256).max);
    }

    function testDeployment() public {
        assertEq(vester.wards($owner), 1);
        assertEq(vester.czar(), $owner);
        assertEq(address(vester.gem()), $token);
        assertEq(token.balanceOf($owner), SUPPLY);
    }

    function testCreateVesting() public {
        uint256 id = vester.create_custom(usr, tot, bgn, tau, eta, mgr, res, bls);

        assertEq(vester.usr(id), usr);
        assertEq(vester.tot(id), tot);
        assertEq(vester.bgn(id), bgn);
        assertEq(vester.clf(id), bgn);
        assertEq(vester.mgr(id), mgr);
        assertEq(vester.res(id), 0);
        assertEq(vester.bls(id), 0);
        assertEq(vester.rxd(id), 0);
    }

    function testAllowVesterToTransferTokens() public {
        uint256 id = vester.create_custom(usr, tot, bgn, tau, eta, mgr, res, bls);

        vm.warp(block.timestamp + 101);

        vm.expectRevert("UNAUTHORIZED");
        vm.prank($recipient);
        vester.vest(id);

        // Enable transfer to vester.
        token.setUserRole($vester, 0, true);

        vm.prank($recipient);
        vester.vest(id);
    }

    function testClaimVesting() public {
        uint256 id = _setVesting();

        vester.vest(id);
        uint256 recipientBalance = token.balanceOf($recipient);
        assertEq(recipientBalance, 0);

        vm.warp(block.timestamp + 110);

        vester.vest(id);
        recipientBalance = token.balanceOf($recipient);
        assertEq(recipientBalance, tot);
    }

    function testAnyoneCanClaimVestingForAnotherRecipient(address _goodGuy) public {
        uint256 id = _setVesting();
        vm.warp(block.timestamp + 110);

        vm.prank(_goodGuy);
        vester.vest(id);
        uint256 recipientBalance = token.balanceOf($recipient);
        assertEq(recipientBalance, tot);
    }

    function _setVesting() internal returns(uint id) {
        id = vester.create_custom(usr, tot, bgn, tau, eta, mgr, res, bls);
        // Enable transfer to vester.
        token.setUserRole($vester, 0, true);
    }
}
